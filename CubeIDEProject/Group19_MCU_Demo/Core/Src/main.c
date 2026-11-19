/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include <stdio.h>
#include <string.h>

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
typedef struct
{
    uint8_t portStatus;
    uint8_t threatID;
    uint8_t deviceClass;
    uint8_t interfaceClass;
    uint16_t vendorID;
    uint16_t productID;
} PortStatus;

typedef struct
{
    uint8_t control;
    uint8_t status;
    uint8_t vidHigh;
    uint8_t vidLow;
    uint8_t pidHigh;
    uint8_t pidLow;
    uint8_t deviceClass;
    uint8_t interfaceClass;
} FpgaPortBlock;

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define NUM_PORTS 4

/* FPGA register map */
#define FPGA_ADDR_SYS_STATUS      0x00
#define FPGA_ADDR_SYS_CONTROL     0x01

#define FPGA_ADDR_P0_CONTROL      0x10
#define FPGA_ADDR_P0_STATUS       0x11
#define FPGA_ADDR_P0_VID_HIGH     0x12
#define FPGA_ADDR_P0_VID_LOW      0x13
#define FPGA_ADDR_P0_PID_HIGH     0x14
#define FPGA_ADDR_P0_PID_LOW      0x15
#define FPGA_ADDR_P0_DEV_CLASS    0x16
#define FPGA_ADDR_P0_INT_CLASS    0x17

#define FPGA_PORT_REG_BASE(port)  (0x10 + ((port) * 0x10))

/* FPGA control bits */
#define FPGA_CTRL_MANUAL_KILL     (1 << 7)
#define FPGA_CTRL_CLEAR_FAULT     (1 << 6)

/* FPGA status bits */
#define FPGA_STATUS_KILL_BIT      7
#define FPGA_STATUS_ATTACHED_BIT  6
#define FPGA_STATUS_THREAT_MASK   0x0F

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
SPI_HandleTypeDef hspi1;

UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */
PortStatus ports[4];
uint8_t uartRxByte;
char uartJsonRxBuffer[128];
uint16_t uartJsonRxIndex = 0;

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_SPI1_Init(void);
/* USER CODE BEGIN PFP */
void FPGA_WriteRegister(uint8_t address, uint8_t data);
uint8_t FPGA_ReadRegister(uint8_t address);
void FPGA_ReadPort(uint8_t port, FpgaPortBlock *data);
uint16_t FPGA_GetVID(FpgaPortBlock *data);
uint16_t FPGA_GetPID(FpgaPortBlock *data);
void FPGA_UpdatePortStatus(uint8_t port, FpgaPortBlock *data);
void FPGA_PollPort0(void);
const char *GetPortStateString(uint8_t port);
void SendJsonTelemetry(void);
void ProcessJsonCommand(const char *json);
void FPGA_SetManualKill(uint8_t port, uint8_t enable);
void FPGA_ClearFault(uint8_t port);
void FPGA_RestorePort(uint8_t port);

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_USART2_UART_Init();
  MX_SPI1_Init();
  /* USER CODE BEGIN 2 */
  char msg[] = "MCU ONLINE\r\n";
  ports[0].portStatus = 0x01;
  ports[0].threatID = 0x11;
  ports[0].deviceClass = 0x21;
  ports[0].interfaceClass = 0x03;
  ports[0].vendorID = 0x1234;
  ports[0].productID = 0x5678;

  ports[1].portStatus = 0x02;
  ports[1].threatID = 0x12;
  ports[1].deviceClass = 0x22;
  ports[1].interfaceClass = 0x08;
  ports[1].vendorID = 0x2345;
  ports[1].productID = 0x6789;

  ports[2].portStatus = 0x03;
  ports[2].threatID = 0x13;
  ports[2].deviceClass = 0x23;
  ports[2].interfaceClass = 0x03;
  ports[2].vendorID = 0x3456;
  ports[2].productID = 0x789A;

  ports[3].portStatus = 0x04;
  ports[3].threatID = 0x14;
  ports[3].deviceClass = 0x24;
  ports[3].interfaceClass = 0x08;
  ports[3].vendorID = 0x4567;
  ports[3].productID = 0x89AB;

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  uint32_t lastTelemetry = 0;

  while (1)
  {
      if (HAL_UART_Receive(&huart2, &uartRxByte, 1, 10) == HAL_OK)
      {
          if ((uartRxByte == '\n') || (uartRxByte == '\r'))
          {
              if (uartJsonRxIndex > 0)
              {
                  uartJsonRxBuffer[uartJsonRxIndex] = '\0';

                  ProcessJsonCommand(uartJsonRxBuffer);

                  uartJsonRxIndex = 0;
              }
          }
          else
          {
              if (uartJsonRxIndex < (sizeof(uartJsonRxBuffer) - 1))
              {
                  uartJsonRxBuffer[uartJsonRxIndex++] = uartRxByte;
              }
              else
              {
                  uartJsonRxIndex = 0;
              }
          }
      }

      if ((HAL_GetTick() - lastTelemetry) >= 2000)
      {
          SendJsonTelemetry();
          lastTelemetry = HAL_GetTick();
      }
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = 16;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV4;
  RCC_OscInitStruct.PLL.PLLQ = 4;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_64;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 10;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */

  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */

  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */

  /* USER CODE END USART2_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : SPI_CS_Pin */
  GPIO_InitStruct.Pin = SPI_CS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(SPI_CS_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
void FPGA_WriteRegister(uint8_t address, uint8_t data)
{
    uint8_t txData[2];

    txData[0] = 0x80 | (address & 0x7F);
    txData[1] = data;

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);

    HAL_SPI_Transmit(&hspi1, txData, 2, 100);

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);
}

uint8_t FPGA_ReadRegister(uint8_t address)
{
    uint8_t txData[2];
    uint8_t rxData[2] = {0};

    txData[0] = address & 0x7F;
    txData[1] = 0x00;

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);

    HAL_SPI_TransmitReceive(&hspi1,
                            txData,
                            rxData,
                            2,
                            100);

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);

    return rxData[1];
}

void FPGA_ReadPort(uint8_t port, FpgaPortBlock *data)
{
    if ((port >= NUM_PORTS) || (data == NULL))
    {
        return;
    }

    uint8_t base = FPGA_PORT_REG_BASE(port);

    data->control        = FPGA_ReadRegister(base + 0x00);
    data->status         = FPGA_ReadRegister(base + 0x01);
    data->vidHigh        = FPGA_ReadRegister(base + 0x02);
    data->vidLow         = FPGA_ReadRegister(base + 0x03);
    data->pidHigh        = FPGA_ReadRegister(base + 0x04);
    data->pidLow         = FPGA_ReadRegister(base + 0x05);
    data->deviceClass    = FPGA_ReadRegister(base + 0x06);
    data->interfaceClass = FPGA_ReadRegister(base + 0x07);
}

uint16_t FPGA_GetVID(FpgaPortBlock *data)
{
    if (data == NULL)
    {
        return 0;
    }

    return ((uint16_t)data->vidHigh << 8) | data->vidLow;
}

uint16_t FPGA_GetPID(FpgaPortBlock *data)
{
    if (data == NULL)
    {
        return 0;
    }

    return ((uint16_t)data->pidHigh << 8) | data->pidLow;
}

void FPGA_UpdatePortStatus(uint8_t port, FpgaPortBlock *data)
{
    if ((port >= NUM_PORTS) || (data == NULL))
    {
        return;
    }

    ports[port].portStatus = data->status;
    ports[port].threatID = data->status & FPGA_STATUS_THREAT_MASK;
    ports[port].deviceClass = data->deviceClass;
    ports[port].interfaceClass = data->interfaceClass;
    ports[port].vendorID = FPGA_GetVID(data);
    ports[port].productID = FPGA_GetPID(data);
}

void FPGA_PollPort0(void)
{
    FpgaPortBlock fpgaPort0;

    FPGA_ReadPort(0, &fpgaPort0);
    FPGA_UpdatePortStatus(0, &fpgaPort0);
}

const char *GetPortStateString(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return "DISCONNECTED";
    }

    uint8_t status = ports[port].portStatus;
    uint8_t attached = (status >> FPGA_STATUS_ATTACHED_BIT) & 0x01;
    uint8_t killed = (status >> FPGA_STATUS_KILL_BIT) & 0x01;

    if (!attached)
    {
        return "DISCONNECTED";
    }

    if (killed)
    {
        if (ports[port].threatID == 7)
        {
            return "MANUAL_BLOCKED";
        }

        return "QUARANTINED";
    }

    return "AUTHORIZED";
}

void SendJsonTelemetry(void)
{
    char jsonBuffer[768];

    int len = snprintf(
        jsonBuffer,
        sizeof(jsonBuffer),
        "{\"timestamp_ms\":%lu,\"ports\":["
        "{\"port\":0,\"state\":\"%s\",\"threat_code\":%u,\"vbus_mv\":0,\"current_ma\":0,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"},"
        "{\"port\":1,\"state\":\"%s\",\"threat_code\":%u,\"vbus_mv\":0,\"current_ma\":0,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"},"
        "{\"port\":2,\"state\":\"%s\",\"threat_code\":%u,\"vbus_mv\":0,\"current_ma\":0,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"},"
        "{\"port\":3,\"state\":\"%s\",\"threat_code\":%u,\"vbus_mv\":0,\"current_ma\":0,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"}"
        "]}\r\n",

        HAL_GetTick(),

        GetPortStateString(0),
        ports[0].threatID,
        ports[0].vendorID,
        ports[0].productID,
        ports[0].deviceClass,
        ports[0].interfaceClass,

        GetPortStateString(1),
        ports[1].threatID,
        ports[1].vendorID,
        ports[1].productID,
        ports[1].deviceClass,
        ports[1].interfaceClass,

        GetPortStateString(2),
        ports[2].threatID,
        ports[2].vendorID,
        ports[2].productID,
        ports[2].deviceClass,
        ports[2].interfaceClass,

        GetPortStateString(3),
        ports[3].threatID,
        ports[3].vendorID,
        ports[3].productID,
        ports[3].deviceClass,
        ports[3].interfaceClass
    );

    if ((len > 0) && (len < sizeof(jsonBuffer)))
    {
        HAL_UART_Transmit(&huart2,
                          (uint8_t *)jsonBuffer,
                          len,
                          100);
    }
}

void ProcessJsonCommand(const char *json)
{
    int port = -1;
    const char *portField = strstr(json, "\"port\":");

    if (portField != NULL)
    {
        portField += 7;

        if ((*portField >= '0') && (*portField <= '3'))
        {
            port = *portField - '0';
        }
    }

    if (port < 0)
    {
        return;
    }

    char response[64];

    if (strstr(json, "\"cmd\":\"isolate_port\"") != NULL)
    {
        FPGA_SetManualKill((uint8_t)port, 1);

        int len = snprintf(response,
                           sizeof(response),
                           "JSON CMD: isolate_port port=%d\r\n",
                           port);

        HAL_UART_Transmit(&huart2,
                          (uint8_t *)response,
                          len,
                          100);
    }
    else if (strstr(json, "\"cmd\":\"restore_port\"") != NULL)
    {
        FPGA_RestorePort((uint8_t)port);

        int len = snprintf(response,
                           sizeof(response),
                           "JSON CMD: restore_port port=%d\r\n",
                           port);

        HAL_UART_Transmit(&huart2,
                          (uint8_t *)response,
                          len,
                          100);
    }
    else if (strstr(json, "\"cmd\":\"clear_fault\"") != NULL)
    {
        FPGA_ClearFault((uint8_t)port);

        int len = snprintf(response,
                           sizeof(response),
                           "JSON CMD: clear_fault port=%d\r\n",
                           port);

        HAL_UART_Transmit(&huart2,
                          (uint8_t *)response,
                          len,
                          100);
    }
}

void FPGA_SetManualKill(uint8_t port, uint8_t enable)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    uint8_t address = FPGA_PORT_REG_BASE(port);

    if (enable)
    {
        FPGA_WriteRegister(address, FPGA_CTRL_MANUAL_KILL);
    }
    else
    {
        FPGA_WriteRegister(address, 0x00);
    }
}

void FPGA_ClearFault(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    uint8_t address = FPGA_PORT_REG_BASE(port);

    FPGA_WriteRegister(address, FPGA_CTRL_CLEAR_FAULT);
    FPGA_WriteRegister(address, 0x00);
}

void FPGA_RestorePort(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    FPGA_SetManualKill(port, 0);
    FPGA_ClearFault(port);
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
