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
#include <stdlib.h>
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
#define FPGA_SPI_POLL_MS 200
#define FPGA_SPI_XFER_TIMEOUT_MS 5U
#define THREAT_MANUAL_HOST_KILL 7

#define FPGA_ADDR_SYS_STATUS 0x00
#define FPGA_PORT_REG_BASE(port) (0x10u + ((port) * 0x10u))

#define FPGA_CTRL_MANUAL_KILL (1u << 7)
#define FPGA_CTRL_CLEAR_FAULT (1u << 6)
#define FPGA_CTRL_APPROVE_HID (1u << 5)
#define FPGA_CTRL_POLICY_MASK 0x07u
#define FPGA_POLICY_HID_CONFIRM 0x1u

#define FPGA_STATUS_KILL_BIT 7
#define FPGA_STATUS_ATTACHED_BIT 6
#define FPGA_STATUS_HID_PENDING_BIT 4
#define FPGA_STATUS_THREAT_MASK 0x0Fu

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
SPI_HandleTypeDef hspi2;

UART_HandleTypeDef huart1;

/* USER CODE BEGIN PV */
PortStatus ports[NUM_PORTS];
char uartJsonRxBuffer[256];
uint16_t uartJsonRxIndex = 0;
static uint32_t led_until_ms = 0;

/* Polled UART RX ring. */
#define UART_RX_RING_SIZE 256U
static volatile uint8_t uartRxRing[UART_RX_RING_SIZE];
static volatile uint16_t uartRxHead = 0;
static volatile uint16_t uartRxTail = 0;

/* Cleared on SPI transfer failure for the current poll cycle. */
static uint8_t spi_bus_ok = 1;

/* Host confirmed HID on this port. */
static uint8_t hid_mcu_approved[NUM_PORTS];

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_SPI2_Init(void);
/* USER CODE BEGIN PFP */
void StatusLed_On(void);
void StatusLed_Off(void);
void StatusLed_Pulse(uint32_t ms);
void StatusLed_Service(void);
void UartRx_Start(void);
void UartRx_PushByte(uint8_t byte);
void UartRx_Poll(void);
int UartRx_Pop(uint8_t *out);
void UartTx_Recover(void);
int UartTx_Write(const uint8_t *data, uint16_t len, uint32_t timeout_ms);
void PollHostCommands(void);
void FPGA_RearmHidIfNeeded(uint8_t port, const FpgaPortBlock *data);
void USART1_IRQHandler(void);
void FPGA_SpiCsSettle(void);
HAL_StatusTypeDef FPGA_SpiRecoverIfNeeded(HAL_StatusTypeDef st);
uint8_t FPGA_SpiBusOk(void);
void FPGA_WriteRegister(uint8_t address, uint8_t data);
uint8_t FPGA_ReadRegister(uint8_t address);
void FPGA_ReadPort(uint8_t port, FpgaPortBlock *data);
uint16_t FPGA_GetVID(const FpgaPortBlock *data);
uint16_t FPGA_GetPID(const FpgaPortBlock *data);
void FPGA_ApplyPortToState(uint8_t port, const FpgaPortBlock *data);
void FPGA_PollAllPorts(void);
uint8_t FPGA_PolicyBits(uint8_t port);
void FPGA_SetPolicy(uint8_t port, uint8_t policy);
void FPGA_SetManualKill(uint8_t port, uint8_t enable);
void FPGA_ClearFault(uint8_t port);
void FPGA_ApproveHid(uint8_t port);
void FPGA_RestorePort(uint8_t port);
const char *GetPortStateString(uint8_t port);
void SendJsonTelemetry(void);
int JsonGetString(const char *json, const char *key, char *out, size_t out_len);
int JsonGetInt(const char *json, const char *key, int *out);
void ProcessJsonCommand(const char *json);

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
  MX_USART1_UART_Init();
  MX_SPI2_Init();
  /* USER CODE BEGIN 2 */
  memset(ports, 0, sizeof(ports));
  memset(hid_mcu_approved, 0, sizeof(hid_mcu_approved));
  StatusLed_Off();

  for (uint8_t i = 0; i < NUM_PORTS; i++)
  {
      FPGA_SetPolicy(i, FPGA_POLICY_HID_CONFIRM);
  }

  FPGA_PollAllPorts();
  UartRx_Start();
  {
      static const char boot[] = "{\"mcu\":\"uart_bm6\"}\n";
      (void)UartTx_Write((const uint8_t *)boot, (uint16_t)(sizeof(boot) - 1U),
                         200U);
  }
  StatusLed_Pulse(250);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  uint32_t lastSpiPoll = 0;

  while (1)
  {
      StatusLed_Service();
      UartRx_Poll();
      PollHostCommands();

      if ((HAL_GetTick() - lastSpiPoll) >= FPGA_SPI_POLL_MS)
      {
          lastSpiPoll = HAL_GetTick();
          StatusLed_Pulse(30);
          SendJsonTelemetry();
          FPGA_PollAllPorts();
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
  * @brief SPI2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI2_Init(void)
{

  /* USER CODE BEGIN SPI2_Init 0 */

  /* USER CODE END SPI2_Init 0 */

  /* USER CODE BEGIN SPI2_Init 1 */

  /* USER CODE END SPI2_Init 1 */
  hspi2.Instance = SPI2;
  hspi2.Init.Mode = SPI_MODE_MASTER;
  hspi2.Init.Direction = SPI_DIRECTION_2LINES;
  hspi2.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi2.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi2.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi2.Init.NSS = SPI_NSS_SOFT;
  hspi2.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_32;
  hspi2.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi2.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi2.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi2.Init.CRCPolynomial = 10;
  if (HAL_SPI_Init(&hspi2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI2_Init 2 */

  /* USER CODE END SPI2_Init 2 */

}

/**
  * @brief USART1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART1_UART_Init(void)
{

  /* USER CODE BEGIN USART1_Init 0 */

  /* USER CODE END USART1_Init 0 */

  /* USER CODE BEGIN USART1_Init 1 */

  /* USER CODE END USART1_Init 1 */
  huart1.Instance = USART1;
  huart1.Init.BaudRate = 115200;
  huart1.Init.WordLength = UART_WORDLENGTH_8B;
  huart1.Init.StopBits = UART_STOPBITS_1;
  huart1.Init.Parity = UART_PARITY_NONE;
  huart1.Init.Mode = UART_MODE_TX_RX;
  huart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart1.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART1_Init 2 */

  /* USER CODE END USART1_Init 2 */

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
  HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : SPI_CS_Pin (PB12) */
  GPIO_InitStruct.Pin = SPI_CS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(SPI_CS_GPIO_Port, &GPIO_InitStruct);

  GPIO_InitStruct.Pin = LD2_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(LD2_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

/* Reset RX ring and disable USART1 interrupts. */
void UartRx_Start(void)
{
    uartRxHead = 0;
    uartRxTail = 0;
    __HAL_UART_CLEAR_OREFLAG(&huart1);
    HAL_NVIC_DisableIRQ(USART1_IRQn);
    CLEAR_BIT(huart1.Instance->CR1, USART_CR1_RXNEIE);
    CLEAR_BIT(huart1.Instance->CR1, USART_CR1_PEIE);
    CLEAR_BIT(huart1.Instance->CR3, USART_CR3_EIE);
}

/* Push one byte into the RX ring. */
void UartRx_PushByte(uint8_t byte)
{
    uint16_t next = (uint16_t)((uartRxHead + 1U) % UART_RX_RING_SIZE);
    if (next != uartRxTail)
    {
        uartRxRing[uartRxHead] = byte;
        uartRxHead = next;
    }
}

/* Drain USART RXNE into the ring and clear overrun. */
void UartRx_Poll(void)
{
    while (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_RXNE) != RESET)
    {
        UartRx_PushByte((uint8_t)(huart1.Instance->DR & 0xFFU));
    }
    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_ORE) != RESET)
    {
        __HAL_UART_CLEAR_OREFLAG(&huart1);
    }
}

/* Clear UART errors and restore HAL/USART ready state for polled TX. */
void UartTx_Recover(void)
{
    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_RXNE) != RESET)
    {
        UartRx_PushByte((uint8_t)(huart1.Instance->DR & 0xFFU));
    }
    __HAL_UART_CLEAR_OREFLAG(&huart1);
    __HAL_UART_CLEAR_FEFLAG(&huart1);
    __HAL_UART_CLEAR_NEFLAG(&huart1);
    __HAL_UART_CLEAR_PEFLAG(&huart1);

    huart1.gState = HAL_UART_STATE_READY;
    huart1.RxState = HAL_UART_STATE_READY;
    huart1.ErrorCode = HAL_UART_ERROR_NONE;
    huart1.Lock = HAL_UNLOCKED;

    SET_BIT(huart1.Instance->CR1, USART_CR1_UE | USART_CR1_TE | USART_CR1_RE);
    CLEAR_BIT(huart1.Instance->CR1, USART_CR1_RXNEIE);
    HAL_NVIC_DisableIRQ(USART1_IRQn);
}

/* Polled UART transmit. */
int UartTx_Write(const uint8_t *data, uint16_t len, uint32_t timeout_ms)
{
    uint32_t start;
    uint32_t spins;

    if ((data == NULL) || (len == 0U))
    {
        return 0;
    }

    UartTx_Recover();

    start = HAL_GetTick();
    for (uint16_t i = 0; i < len; i++)
    {
        spins = 0;
        while (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_TXE) == RESET)
        {
            spins++;
            if (((HAL_GetTick() - start) > timeout_ms) || (spins > 200000U))
            {
                UartTx_Recover();
                return 0;
            }
            if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_RXNE) != RESET)
            {
                UartRx_PushByte((uint8_t)(huart1.Instance->DR & 0xFFU));
            }
            if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_ORE) != RESET)
            {
                __HAL_UART_CLEAR_OREFLAG(&huart1);
            }
        }
        huart1.Instance->DR = data[i];
    }

    spins = 0;
    while (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_TC) == RESET)
    {
        spins++;
        if (((HAL_GetTick() - start) > timeout_ms) || (spins > 200000U))
        {
            UartTx_Recover();
            return 0;
        }
        if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_RXNE) != RESET)
        {
            UartRx_PushByte((uint8_t)(huart1.Instance->DR & 0xFFU));
        }
    }

    huart1.gState = HAL_UART_STATE_READY;
    return 1;
}

/* Pop one byte from the RX ring. */
int UartRx_Pop(uint8_t *out)
{
    uint16_t tail;
    uint16_t head;

    if (out == NULL)
    {
        return 0;
    }

    tail = uartRxTail;
    head = uartRxHead;
    if (tail == head)
    {
        return 0;
    }

    *out = uartRxRing[tail];
    uartRxTail = (uint16_t)((tail + 1U) % UART_RX_RING_SIZE);
    return 1;
}

/* USART1 ISR. */
void USART1_IRQHandler(void)
{
    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_ORE))
    {
        volatile uint32_t sr = huart1.Instance->SR;
        volatile uint32_t dr = huart1.Instance->DR;
        (void)sr;
        (void)dr;
    }

    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_RXNE))
    {
        uint8_t byte = (uint8_t)(huart1.Instance->DR & 0xFFU);
        uint16_t next = (uint16_t)((uartRxHead + 1U) % UART_RX_RING_SIZE);
        if (next != uartRxTail)
        {
            uartRxRing[uartRxHead] = byte;
            uartRxHead = next;
        }
    }

    if (__HAL_UART_GET_FLAG(&huart1, UART_FLAG_FE) ||
        __HAL_UART_GET_FLAG(&huart1, UART_FLAG_NE) ||
        __HAL_UART_GET_FLAG(&huart1, UART_FLAG_PE))
    {
        __HAL_UART_CLEAR_FEFLAG(&huart1);
        __HAL_UART_CLEAR_NEFLAG(&huart1);
        __HAL_UART_CLEAR_PEFLAG(&huart1);
        volatile uint32_t dr = huart1.Instance->DR;
        (void)dr;
    }
}

/* Assemble JSON commands from the RX ring. */
void PollHostCommands(void)
{
    uint8_t c;

    while (UartRx_Pop(&c))
    {
        if (c == '\r')
        {
            continue;
        }
        if (c == '\n')
        {
            if (uartJsonRxIndex > 0U)
            {
                uartJsonRxBuffer[uartJsonRxIndex] = '\0';
                ProcessJsonCommand(uartJsonRxBuffer);
                uartJsonRxIndex = 0;
            }
            continue;
        }
        if ((uartJsonRxIndex + 1U) < sizeof(uartJsonRxBuffer))
        {
            uartJsonRxBuffer[uartJsonRxIndex++] = (char)c;
        }
        else
        {
            uartJsonRxIndex = 0;
        }
    }
}

/* Turn LD2 on. */
void StatusLed_On(void)
{
    HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_SET);
}

/* Turn LD2 off. */
void StatusLed_Off(void)
{
    HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);
}

/* Pulse LD2. */
void StatusLed_Pulse(uint32_t ms)
{
    StatusLed_On();
    led_until_ms = HAL_GetTick() + ms;
}

/* Expire a pending LED pulse. */
void StatusLed_Service(void)
{
    if ((led_until_ms != 0U) &&
        ((int32_t)(HAL_GetTick() - led_until_ms) >= 0))
    {
        StatusLed_Off();
        led_until_ms = 0U;
    }
}

/* Short wait for SPI chip-select. */
void FPGA_SpiCsSettle(void)
{
    for (volatile uint32_t i = 0; i < 50U; i++)
    {
    }
}

/* On SPI error mark bus bad, deassert CS, and reset the SPI peripheral. */
HAL_StatusTypeDef FPGA_SpiRecoverIfNeeded(HAL_StatusTypeDef st)
{
    if (st == HAL_OK)
    {
        return st;
    }
    spi_bus_ok = 0;
    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);
    CLEAR_BIT(hspi2.Instance->CR1, SPI_CR1_SPE);
    if (__HAL_SPI_GET_FLAG(&hspi2, SPI_FLAG_RXNE) != RESET)
    {
        volatile uint32_t drain = hspi2.Instance->DR;
        (void)drain;
    }
    __HAL_SPI_CLEAR_OVRFLAG(&hspi2);
    SET_BIT(hspi2.Instance->CR1, SPI_CR1_SPE);
    hspi2.State = HAL_SPI_STATE_READY;
    hspi2.ErrorCode = HAL_SPI_ERROR_NONE;
    return st;
}

/* Return 1 if the current SPI poll cycle is still healthy. */
uint8_t FPGA_SpiBusOk(void)
{
    return spi_bus_ok;
}

/* Write one FPGA register. */
void FPGA_WriteRegister(uint8_t address, uint8_t data)
{
    uint8_t txData[2];

    if (!spi_bus_ok)
    {
        return;
    }

    txData[0] = (uint8_t)(0x80u | (address & 0x7Fu));
    txData[1] = data;

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);
    FPGA_SpiCsSettle();
    (void)FPGA_SpiRecoverIfNeeded(
        HAL_SPI_Transmit(&hspi2, txData, 2, FPGA_SPI_XFER_TIMEOUT_MS));
    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);
    FPGA_SpiCsSettle();
}

/* Read one FPGA register. */
uint8_t FPGA_ReadRegister(uint8_t address)
{
    uint8_t txData[2];
    uint8_t rxData[2] = {0};

    if (!spi_bus_ok)
    {
        return 0;
    }

    txData[0] = (uint8_t)(address & 0x7Fu);
    txData[1] = 0x00;

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);
    FPGA_SpiCsSettle();
    (void)FPGA_SpiRecoverIfNeeded(HAL_SPI_TransmitReceive(
        &hspi2, txData, rxData, 2, FPGA_SPI_XFER_TIMEOUT_MS));
    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);
    FPGA_SpiCsSettle();

    return rxData[1];
}

/* Read the eight-byte control/status/descriptor block for one port. */
void FPGA_ReadPort(uint8_t port, FpgaPortBlock *data)
{
    if ((port >= NUM_PORTS) || (data == NULL) || !spi_bus_ok)
    {
        return;
    }

    uint8_t base = (uint8_t)FPGA_PORT_REG_BASE(port);

    data->control = FPGA_ReadRegister((uint8_t)(base + 0x00));
    if (!spi_bus_ok)
    {
        return;
    }
    data->status = FPGA_ReadRegister((uint8_t)(base + 0x01));
    data->vidHigh = FPGA_ReadRegister((uint8_t)(base + 0x02));
    data->vidLow = FPGA_ReadRegister((uint8_t)(base + 0x03));
    data->pidHigh = FPGA_ReadRegister((uint8_t)(base + 0x04));
    data->pidLow = FPGA_ReadRegister((uint8_t)(base + 0x05));
    data->deviceClass = FPGA_ReadRegister((uint8_t)(base + 0x06));
    data->interfaceClass = FPGA_ReadRegister((uint8_t)(base + 0x07));
}

/* Combine VID high/low bytes from a port block. */
uint16_t FPGA_GetVID(const FpgaPortBlock *data)
{
    if (data == NULL)
    {
        return 0;
    }
    return (uint16_t)(((uint16_t)data->vidHigh << 8) | data->vidLow);
}

/* Combine PID high/low bytes from a port block. */
uint16_t FPGA_GetPID(const FpgaPortBlock *data)
{
    if (data == NULL)
    {
        return 0;
    }
    return (uint16_t)(((uint16_t)data->pidHigh << 8) | data->pidLow);
}

/* Pulse kill if HID is live without MCU confirm, re-arming pending hold. */
void FPGA_RearmHidIfNeeded(uint8_t port, const FpgaPortBlock *data)
{
    uint8_t attached;
    uint8_t killed;
    uint8_t hid_pending;

    if ((port >= NUM_PORTS) || (data == NULL))
    {
        return;
    }

    attached = (uint8_t)((data->status >> FPGA_STATUS_ATTACHED_BIT) & 0x01u);
    killed = (uint8_t)((data->status >> FPGA_STATUS_KILL_BIT) & 0x01u);
    hid_pending =
        (uint8_t)((data->status >> FPGA_STATUS_HID_PENDING_BIT) & 0x01u);

    if (!attached)
    {
        hid_mcu_approved[port] = 0;
        return;
    }

    if (!hid_mcu_approved[port] && !hid_pending && !killed &&
        (data->interfaceClass == 0x03u))
    {
        FPGA_SetManualKill(port, 1);
        FPGA_SetManualKill(port, 0);
    }
}

/* Copy one FPGA port block into the GUI-facing PortStatus cache. */
void FPGA_ApplyPortToState(uint8_t port, const FpgaPortBlock *data)
{
    if ((port >= NUM_PORTS) || (data == NULL))
    {
        return;
    }

    ports[port].portStatus = data->status;
    ports[port].threatID = (uint8_t)(data->status & FPGA_STATUS_THREAT_MASK);
    ports[port].deviceClass = data->deviceClass;
    ports[port].interfaceClass = data->interfaceClass;
    ports[port].vendorID = FPGA_GetVID(data);
    ports[port].productID = FPGA_GetPID(data);

    if (((data->status >> FPGA_STATUS_ATTACHED_BIT) & 0x01u) == 0u)
    {
        hid_mcu_approved[port] = 0;
    }
}

/* Poll all four ports over SPI; stop early if the bus fails. */
void FPGA_PollAllPorts(void)
{
    FpgaPortBlock block;

    spi_bus_ok = 1;
    (void)FPGA_ReadRegister(FPGA_ADDR_SYS_STATUS);
    for (uint8_t i = 0; i < NUM_PORTS; i++)
    {
        if (!spi_bus_ok)
        {
            break;
        }
        FPGA_ReadPort(i, &block);
        if (spi_bus_ok)
        {
            FPGA_RearmHidIfNeeded(i, &block);
            FPGA_ReadPort(i, &block);
            if (spi_bus_ok)
            {
                FPGA_ApplyPortToState(i, &block);
            }
        }
    }
}

/* Read the policy nibble from a port control register. */
uint8_t FPGA_PolicyBits(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return 0;
    }
    return (uint8_t)(FPGA_ReadRegister((uint8_t)FPGA_PORT_REG_BASE(port)) &
                     FPGA_CTRL_POLICY_MASK);
}

/* Write HID/storage policy bits while preserving other control flags. */
void FPGA_SetPolicy(uint8_t port, uint8_t policy)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    uint8_t addr = (uint8_t)FPGA_PORT_REG_BASE(port);
    uint8_t cur = FPGA_ReadRegister(addr);
    uint8_t next = (uint8_t)((cur & (uint8_t)~FPGA_CTRL_POLICY_MASK) |
                             (policy & FPGA_CTRL_POLICY_MASK));
    FPGA_WriteRegister(addr, next);
}

/* Assert or clear manual kill on a port (policy bits preserved). */
void FPGA_SetManualKill(uint8_t port, uint8_t enable)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    uint8_t addr = (uint8_t)FPGA_PORT_REG_BASE(port);
    uint8_t policy = FPGA_PolicyBits(port);
    FPGA_WriteRegister(addr, enable ? (uint8_t)(FPGA_CTRL_MANUAL_KILL | policy)
                                    : policy);
}

/* Pulse clear_fault on a port, then restore policy-only control. */
void FPGA_ClearFault(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    uint8_t addr = (uint8_t)FPGA_PORT_REG_BASE(port);
    uint8_t policy = FPGA_PolicyBits(port);
    FPGA_WriteRegister(addr, (uint8_t)(FPGA_CTRL_CLEAR_FAULT | policy));
    FPGA_WriteRegister(addr, policy);
}

/* Pulse approve_hid on a port, then restore policy-only control. */
void FPGA_ApproveHid(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return;
    }

    uint8_t addr = (uint8_t)FPGA_PORT_REG_BASE(port);
    uint8_t policy = FPGA_PolicyBits(port);
    FPGA_WriteRegister(addr, (uint8_t)(FPGA_CTRL_APPROVE_HID | policy));
    FPGA_WriteRegister(addr, policy);
}

/* Clear manual kill and sticky fault on a port. */
void FPGA_RestorePort(uint8_t port)
{
    FPGA_SetManualKill(port, 0);
    FPGA_ClearFault(port);
}

/* Map FPGA status bits to the host-facing port state string. */
const char *GetPortStateString(uint8_t port)
{
    if (port >= NUM_PORTS)
    {
        return "DISCONNECTED";
    }

    uint8_t status = ports[port].portStatus;
    uint8_t attached = (uint8_t)((status >> FPGA_STATUS_ATTACHED_BIT) & 0x01u);
    uint8_t killed = (uint8_t)((status >> FPGA_STATUS_KILL_BIT) & 0x01u);
    uint8_t hid_pending =
        (uint8_t)((status >> FPGA_STATUS_HID_PENDING_BIT) & 0x01u);

    if (!attached)
    {
        return "DISCONNECTED";
    }
    if (hid_pending)
    {
        return "PENDING_HID_CONFIRM";
    }
    if (killed)
    {
        if (ports[port].threatID == THREAT_MANUAL_HOST_KILL)
        {
            return "MANUAL_BLOCKED";
        }
        return "QUARANTINED";
    }
    if (!hid_mcu_approved[port] &&
        (ports[port].interfaceClass == 0x03u ||
         (ports[port].vendorID == 0u && ports[port].productID == 0u)))
    {
        return "PENDING_HID_CONFIRM";
    }
    return "AUTHORIZED";
}

/* Build and send one JSON telemetry frame for all four ports. */
void SendJsonTelemetry(void)
{
    static char jsonBuffer[768];

    int len = snprintf(
        jsonBuffer,
        sizeof(jsonBuffer),
        "{\"timestamp_ms\":%lu,\"ports\":["
        "{\"port\":0,\"state\":\"%s\",\"threat_code\":%u,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"},"
        "{\"port\":1,\"state\":\"%s\",\"threat_code\":%u,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"},"
        "{\"port\":2,\"state\":\"%s\",\"threat_code\":%u,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"},"
        "{\"port\":3,\"state\":\"%s\",\"threat_code\":%u,\"vid\":\"0x%04X\",\"pid\":\"0x%04X\",\"dev_class\":\"0x%02X\",\"int_class\":\"0x%02X\"}"
        "]}\n",
        (unsigned long)HAL_GetTick(),
        GetPortStateString(0), ports[0].threatID, ports[0].vendorID,
        ports[0].productID, ports[0].deviceClass, ports[0].interfaceClass,
        GetPortStateString(1), ports[1].threatID, ports[1].vendorID,
        ports[1].productID, ports[1].deviceClass, ports[1].interfaceClass,
        GetPortStateString(2), ports[2].threatID, ports[2].vendorID,
        ports[2].productID, ports[2].deviceClass, ports[2].interfaceClass,
        GetPortStateString(3), ports[3].threatID, ports[3].vendorID,
        ports[3].productID, ports[3].deviceClass, ports[3].interfaceClass);

    if (len < 0)
    {
        return;
    }
    if ((size_t)len >= sizeof(jsonBuffer))
    {
        len = (int)sizeof(jsonBuffer) - 1;
        jsonBuffer[len] = '\0';
    }
    (void)UartTx_Write((const uint8_t *)jsonBuffer, (uint16_t)len, 200U);
}

/* Extract a quoted string value for a JSON key. */
int JsonGetString(const char *json, const char *key, char *out, size_t out_len)
{
    char pattern[48];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(json, pattern);
    if (p == NULL)
    {
        return 0;
    }
    p = strchr(p + strlen(pattern), ':');
    if (p == NULL)
    {
        return 0;
    }
    p++;
    while (*p == ' ' || *p == '\t')
    {
        p++;
    }
    if (*p != '"')
    {
        return 0;
    }
    p++;
    size_t i = 0;
    while (*p && *p != '"' && (i + 1U) < out_len)
    {
        out[i++] = *p++;
    }
    out[i] = '\0';
    return i > 0U;
}

/* Extract an integer value for a JSON key. */
int JsonGetInt(const char *json, const char *key, int *out)
{
    char pattern[48];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(json, pattern);
    if (p == NULL)
    {
        return 0;
    }
    p = strchr(p + strlen(pattern), ':');
    if (p == NULL)
    {
        return 0;
    }
    p++;
    while (*p == ' ' || *p == '\t')
    {
        p++;
    }
    char *end = NULL;
    long v = strtol(p, &end, 10);
    if (end == p)
    {
        return 0;
    }
    *out = (int)v;
    return 1;
}

/* Handle host commands: isolate, restore, clear_fault, confirm_hid. */
void ProcessJsonCommand(const char *json)
{
    char type_buf[16] = {0};
    char cmd_buf[32] = {0};
    int port_id = -1;

    if (JsonGetString(json, "type", type_buf, sizeof(type_buf)))
    {
        if (strcmp(type_buf, "command") != 0)
        {
            return;
        }
    }
    if (!JsonGetString(json, "cmd", cmd_buf, sizeof(cmd_buf)))
    {
        return;
    }
    if (!JsonGetInt(json, "port", &port_id) || port_id < 0 ||
        port_id >= NUM_PORTS)
    {
        return;
    }

    if (strcmp(cmd_buf, "isolate_port") == 0)
    {
        hid_mcu_approved[port_id] = 0;
        FPGA_SetManualKill((uint8_t)port_id, 1);
        StatusLed_Pulse(120);
    }
    else if (strcmp(cmd_buf, "restore_port") == 0)
    {
        hid_mcu_approved[port_id] = 0;
        FPGA_RestorePort((uint8_t)port_id);
        StatusLed_Pulse(120);
    }
    else if (strcmp(cmd_buf, "clear_fault") == 0)
    {
        FPGA_ClearFault((uint8_t)port_id);
        StatusLed_Pulse(120);
    }
    else if (strcmp(cmd_buf, "confirm_hid") == 0)
    {
        hid_mcu_approved[port_id] = 1;
        FPGA_ApproveHid((uint8_t)port_id);
        StatusLed_Pulse(120);
    }
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
