#include <stdint.h>
#include <string.h>

/* config */
#include <sdk_config.h>

/* platform */
#include <nordic_common.h>
#include <boards.h>
#include <nrf.h>
//#include <nrf52810.h>

/* IO */
#include <nrf_gpio.h>
#include <nrf_drv_timer.h>
#include <nrf_drv_pwm.h>
#include <nrf_pwm.h>

/* utils */
#include <app_error.h>
#include <app_timer.h>
#include <nrf_log.h>
#include <nrf_log_ctrl.h>
#include <nrf_log_default_backends.h>

/* softdevice */
#include <nrf_sdh.h>
#include <nrf_sdh_ble.h>

/* BLE */
#include <ble.h>
#include <ble_gap.h>
#include <ble_err.h>
#include <ble_hci.h>
#include <ble_srv_common.h>
#include <ble_advdata.h>
#include <ble_conn_params.h>
#include <nrf_ble_gatt.h>



/*
	port definitions

PWM will output these 4 ports simultaneously.
*/
#define OUT_PWMa	22
#define OUT_PWMb	23
#define OUT_PWMc	24
#define OUT_PWMd	20 /* aka: LED4 */



/*
	PWM

Pwm duty cycle is an array of 4 channels repeated twice (two periods).

PWM value is statically set to 25% of COUNTERTOP.
*/
static uint16_t			pwm0_duty[] = {
	0x64, 0x64, 0x64, 0x64,
	0x64, 0x64, 0x64, 0x64
};

/* Keep everything in Data RAM for DMA access,
	hence static but not const.
*/
static nrf_drv_pwm_t		pwm0_inst = NRF_DRV_PWM_INSTANCE(0);
static nrf_pwm_sequence_t	pwm0_seq = {
	.values = { .p_raw = pwm0_duty },
	.length = sizeof(pwm0_duty) / sizeof(pwm0_duty[0]),
	/* These values ignored in NRF_PWM_STEP_TRIGGERED mode: */ 
	.repeats = 0,
	.end_delay = 0
};
static nrf_drv_pwm_config_t	pwm0_conf = {
	.output_pins = { /* channels 1-4 */
		OUT_PWMa,
		OUT_PWMb,
		OUT_PWMc,
		OUT_PWMd
	},
	.irq_priority = PWM_DEFAULT_CONFIG_IRQ_PRIORITY,
	.base_clock   = NRF_PWM_CLK_16MHz,
	.count_mode   = NRF_PWM_MODE_UP,
	.top_value    = 400,
	.load_mode    = NRF_PWM_LOAD_INDIVIDUAL,/* Each channel own duty cycle */
	.step_mode    = NRF_PWM_STEP_AUTO	/* ? */
};

/*	pwm_init()
*/
void pwm_init()
{

	nrf_gpio_cfg_output(OUT_PWMa);
	nrf_gpio_cfg_output(OUT_PWMb);
	nrf_gpio_cfg_output(OUT_PWMc);
	nrf_gpio_cfg_output(OUT_PWMd);

	/* start pwm */
	APP_ERROR_CHECK(
		nrf_drv_pwm_init(&pwm0_inst, &pwm0_conf, NULL)
		);
	nrf_drv_pwm_simple_playback(&pwm0_inst, &pwm0_seq, 1, NRF_DRV_PWM_FLAG_LOOP);
}



/*
	BLE
*/
#define APP_FEATURE_NOT_SUPPORTED       BLE_GATT_STATUS_ATTERR_APP_BEGIN + 2
	/**< Reply when unsupported features are requested. */

#define DEVICE_NAME                     "nrf52_pwm_lfo"
	/**< Name of device. Will be included in the advertising data. */
#define COMPANY_IDENTIFIER              0xFFFF
	/**< Testing. */

#define APP_BLE_OBSERVER_PRIO           3
	/**< Application's BLE observer priority. You shouldn't need to modify this value. */
#define APP_BLE_CONN_CFG_TAG            1
	/**< A tag identifying the SoftDevice BLE configuration. */

#define APP_ADV_INTERVAL                64
	/**< The advertising interval (in units of 0.625 ms; this value corresponds to 40 ms). */
#define APP_ADV_TIMEOUT			-1 /* never timeout */
#define APP_ADV_TIMEOUT_IN_SECONDS      BLE_GAP_ADV_TIMEOUT_GENERAL_UNLIMITED
	/**< The advertising time-out (in units of seconds). When set to 0, we will never time out. */

#define MIN_CONN_INTERVAL               MSEC_TO_UNITS(100, UNIT_1_25_MS)
	/**< Minimum acceptable connection interval (0.5 seconds). */
#define MAX_CONN_INTERVAL               MSEC_TO_UNITS(200, UNIT_1_25_MS)
	/**< Maximum acceptable connection interval (1 second). */
#define SLAVE_LATENCY                   0
	/**< Slave latency. */
#define CONN_SUP_TIMEOUT                MSEC_TO_UNITS(4000, UNIT_10_MS)
	/**< Connection supervisory time-out (4 seconds). */

#define FIRST_CONN_PARAMS_UPDATE_DELAY  APP_TIMER_TICKS(20000)
	/**< Time from initiating event (connect or start of notification)
		to first time sd_ble_gap_conn_param_update is called (15 seconds).
	*/
#define NEXT_CONN_PARAMS_UPDATE_DELAY   APP_TIMER_TICKS(40000)
	/**< Time between each call to sd_ble_gap_conn_param_update after the first call (30 seconds per BLE spec). */
#define MAX_CONN_PARAMS_UPDATE_COUNT    3
	/**< Number of attempts before giving up the connection parameter negotiation. */

#define DEAD_BEEF                       0xDEADBEEF
	/**< Value used as error code on stack dump, can be used to identify stack location on stack unwind. */


NRF_BLE_GATT_DEF(m_gatt);                                                       /**< GATT module instance. */

static uint16_t	conn_handle = BLE_CONN_HANDLE_INVALID;	/* Handle of the current connection. */

uint16_t	s_handle = 0;			/* service handle */
ble_uuid_t	s_uuids[1] = { 0 };		/* Array of service UUIDs (there's only one,
							but it's passed in an array
							for advertising.
						*/


/*	ble_err()
Callback function for asserts in the SoftDevice.
*/
void ble_err(	uint16_t line_num,
		const uint8_t * p_file_name)
{ 
	NRF_LOG_ERROR("%s: %d", p_file_name, line_num);
	sd_nvic_SystemReset();
}

/*	ble_err_callback()
Just a typecast for APP_ERROR_HANDLER()
*/
void ble_err_callback(uint32_t nrf_error)
{
	UNUSED_VARIABLE(nrf_error);
	ble_err(__LINE__, (uint8_t *)__FILE__);
}

/*	gap_params_init()
gap == General Attributes Profile
*/
static void gap_params_init(void)
{
	ble_gap_conn_sec_mode_t sec_mode = { 0 };
	BLE_GAP_CONN_SEC_MODE_SET_OPEN(&sec_mode);
	APP_ERROR_CHECK(
		sd_ble_gap_device_name_set(&sec_mode,
                                          (const uint8_t *)DEVICE_NAME,
                                          strlen(DEVICE_NAME))
		);

	/* ppcp == Peripheral Preferred Connection Parameters */
	ble_gap_conn_params_t   gap_conn_params = {
					.min_conn_interval = MIN_CONN_INTERVAL,
					.max_conn_interval = MAX_CONN_INTERVAL,
					.slave_latency     = SLAVE_LATENCY,
					.conn_sup_timeout  = CONN_SUP_TIMEOUT
				};
	APP_ERROR_CHECK(
		sd_ble_gap_ppcp_set(&gap_conn_params)
		);

	/* appearance */
	APP_ERROR_CHECK(
		sd_ble_gap_appearance_set(BLE_APPEARANCE_UNKNOWN)
		);
}

/*	services_init()
Init services and characteristics
*/
static void services_init()
{
	/*
		generic service
	*/
	#define TEST_SERVICE_BE { 0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01 }
	ble_uuid128_t ble_uuid128 = { TEST_SERVICE_BE };
	/* Use bytes 12 and 13 (0-based) as our 16-bit UUID.
	Note that 'ble_uuid128' is big-endian, but we assign to a little-endian uint16_t.
	*/
	s_uuids[0].uuid =  ble_uuid128.uuid128[12] | ble_uuid128.uuid128[13] << 8;
	/* Map the 16-bit uuid to the full 128-bit UUID in the SD */
	APP_ERROR_CHECK(
		sd_ble_uuid_vs_add(&ble_uuid128, &s_uuids[0].type)
		);
	APP_ERROR_CHECK(
		sd_ble_gatts_service_add(BLE_GATTS_SRVC_TYPE_PRIMARY, 
					&s_uuids[0], 
					&s_handle)
		);

	/*
		Characteristics.

	No characteristics implemented.
	*/
}

static ble_gap_adv_params_t     m_adv_params = {
	.type        = BLE_GAP_ADV_TYPE_ADV_IND,
	.p_peer_addr = NULL,
	.fp          = BLE_GAP_ADV_FP_ANY,
	.interval    = APP_ADV_INTERVAL,
	.timeout     = APP_ADV_TIMEOUT
};

/*	advertising_init()
*/
static void advertising_init(void)
{
	ble_advdata_manuf_data_t manuf_data = {
		.company_identifier = COMPANY_IDENTIFIER,
		.data.size          = 0,
		.data.p_data        = NULL
	};

	ble_advdata_t advdata = {
		.name_type		= BLE_ADVDATA_FULL_NAME,
		.include_appearance	= false, /* unsure whether we need this */
		.flags			= BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE,
		.p_manuf_specific_data	= &manuf_data
	};

	ble_advdata_t scanrsp = {
			.uuids_complete.uuid_cnt = sizeof(s_uuids) / sizeof(s_uuids[0]),
			.uuids_complete.p_uuids  = s_uuids
	};

	APP_ERROR_CHECK(
		ble_advdata_set(&advdata, &scanrsp)
		);
}

/*	conn_params_init()
*/
static void conn_params_init(void)
{
	ble_conn_params_init_t cp_init = {
		.p_conn_params                  = NULL,
		.first_conn_params_update_delay = FIRST_CONN_PARAMS_UPDATE_DELAY,
		.next_conn_params_update_delay  = NEXT_CONN_PARAMS_UPDATE_DELAY,
		.max_conn_params_update_count   = MAX_CONN_PARAMS_UPDATE_COUNT,
		.start_on_notify_cccd_handle    = BLE_GATT_HANDLE_INVALID,
		.disconnect_on_fail             = true,
		.evt_handler                    = NULL,
		.error_handler                  = ble_err_callback
	};

	APP_ERROR_CHECK(
		ble_conn_params_init(&cp_init)
		);
}


/*	ble_evt_handler()
Handle ble events.
*/
static void ble_evt_handler(ble_evt_t const * event, void * p_context)
{
	UNUSED_PARAMETER(p_context);

	switch (event->header.evt_id) {
	/*
		connect/disconnect
	*/
	case BLE_GAP_EVT_CONNECTED:
		NRF_LOG_INFO("connected");
		break;

	case BLE_GAP_EVT_DISCONNECTED:
		NRF_LOG_INFO("disconnected");
		break;

	/*
		handle writes
	*/
	case BLE_GATTS_EVT_WRITE:
		NRF_LOG_INFO("write");
		break;

	/*
		Nordic's boilerplate
	*/
	case BLE_GAP_EVT_SEC_PARAMS_REQUEST:
		NRF_LOG_INFO("BLE_GAP_EVT_SEC_PARAMS_REQUEST");
		/* Pairing not supported */
		APP_ERROR_CHECK(
			sd_ble_gap_sec_params_reply(conn_handle,
				BLE_GAP_SEC_STATUS_PAIRING_NOT_SUPP,
				NULL,
				NULL)
			);
		break;
	case BLE_GATTS_EVT_SYS_ATTR_MISSING:
		NRF_LOG_INFO("BLE_GATTS_EVT_SYS_ATTR_MISSING");
		/* No system attributes have been stored. */
		APP_ERROR_CHECK(
			sd_ble_gatts_sys_attr_set(conn_handle, NULL, 0, 0)
			);
		break;
	case BLE_GATTC_EVT_TIMEOUT:
		/* Disconnect on GATT Client timeout event. */
		NRF_LOG_DEBUG("GATT Client Timeout.");
		APP_ERROR_CHECK(
			sd_ble_gap_disconnect(event->evt.gattc_evt.conn_handle,
				BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION)
			);
		break;
	case BLE_GATTS_EVT_TIMEOUT:
		/* Disconnect on GATT Server timeout event */
		NRF_LOG_DEBUG("GATT Server Timeout.");
		APP_ERROR_CHECK(
			sd_ble_gap_disconnect(event->evt.gatts_evt.conn_handle,
				BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION)
			);
		break;
	case BLE_EVT_USER_MEM_REQUEST:
		NRF_LOG_INFO("BLE_EVT_USER_MEM_REQUEST");
		APP_ERROR_CHECK(
			sd_ble_user_mem_reply(event->evt.gattc_evt.conn_handle, NULL)
			);
		break;

	/* scan report */
	case BLE_GAP_EVT_ADV_REPORT:
		NRF_LOG_INFO("scan report");
		break;

	default:
		NRF_LOG_WARNING("cannot handle BLE event 0x%x", event->header.evt_id);
		NRF_LOG_WARNING("BLE_GAP_EVT_BASE @ 0x%x", BLE_GAP_EVT_BASE);

		break;
	}

	/* flush logs once on exit */
	NRF_LOG_FLUSH();
}

/*	ble_stack_init()
Initialize SoftDevice and BLE event interrupt
*/
static void ble_stack_init(void)
{
	APP_ERROR_CHECK(
		nrf_sdh_enable_request()
		);

	/* default BLE config; check RAM start address */
	uint32_t ram_start = 0;
	APP_ERROR_CHECK(
		nrf_sdh_ble_default_cfg_set(APP_BLE_CONN_CFG_TAG, &ram_start)
		);
	APP_ERROR_CHECK(
		nrf_sdh_ble_enable(&ram_start)
		);

	/* ble event handler */
	NRF_SDH_BLE_OBSERVER(m_ble_observer, APP_BLE_OBSERVER_PRIO, ble_evt_handler, NULL);
}


/*	main()
*/
int main(void)
{
	/* init board */
	bsp_board_leds_init(); /* one of the PWMs outputs to LED4 for visual check */
	APP_ERROR_CHECK(
		app_timer_init()
		);
	/* init logging */
	APP_ERROR_CHECK(
		NRF_LOG_INIT(NULL)
		);
	NRF_LOG_DEFAULT_BACKENDS_INIT();

	/* ble init */
	ble_stack_init();
	gap_params_init();
	APP_ERROR_CHECK(
		nrf_ble_gatt_init(&m_gatt, NULL)
		);
	services_init();
	advertising_init();
	conn_params_init();

	/* start PWM */
	pwm_init();

#ifndef NO_ADVERT
	/* start advertising */
	APP_ERROR_CHECK(
		sd_ble_gap_adv_start(&m_adv_params, APP_BLE_CONN_CFG_TAG)
		);
#else
	UNUSED_VARIABLE(m_adv_params);
#endif

#ifndef NO_SCAN
	/* scan for other devices */
	static ble_gap_scan_params_t scan_params = {
		.active = 0,
		.use_whitelist = 0,
		.adv_dir_report = 0,
		.interval = APP_ADV_INTERVAL,	/* same interval as advertisement */
		.window = APP_ADV_INTERVAL,	/* no idea what this does */
		.timeout = 0			/* never time out */
	};
	APP_ERROR_CHECK(
		sd_ble_gap_scan_start(&scan_params)
		);
#endif

	/* event loop */
	NRF_LOG_INFO("running");
	NRF_LOG_FLUSH();
	while (sd_app_evt_wait() == NRF_SUCCESS)
		;

	return 0;
}
