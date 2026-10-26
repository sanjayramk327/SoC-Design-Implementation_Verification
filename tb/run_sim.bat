@echo off
setlocal enabledelayedexpansion
title MorphoSoC GTKWave Demo Runner

echo.
echo  ================================================================
echo    MorphoSoC Interactive Demo Runner
echo    Compiles, simulates, then opens GTKWave automatically
echo  ================================================================
echo.
echo   [1] UDB 2.0  -- Single-Cycle Autonomous Context Morphing
echo   [2] HSIOM    -- Self-Healing Autonomous Pin Failover
echo   [3] UART TX  -- Transmit "MorphoSoC!" over serial
echo   [4] SNN      -- Neuromorphic Gesture Classification
echo   [5] Run ALL  -- All demos sequentially
echo.
set /p CHOICE= Enter choice (1-5): 

if "%CHOICE%"=="1" goto RUN_UDB
if "%CHOICE%"=="2" goto RUN_HSIOM
if "%CHOICE%"=="3" goto RUN_UART
if "%CHOICE%"=="4" goto RUN_SNN
if "%CHOICE%"=="5" goto RUN_ALL
echo Unknown choice, exiting.
goto END

:: ============================================================
:RUN_UDB
echo.
echo [*] Building Demo 1: UDB 2.0 Context Morphing...
iverilog -g2005 -Wall -o demo_udb_morph.out ^
    demo_udb_morph.v ^
    ..\rtl\udb\udb_top.v ^
    ..\rtl\udb\udb_morph_controller.v ^
    ..\rtl\udb\udb_datapath.v ^
    ..\rtl\udb\udb_macrocell.v ^
    ..\rtl\bus\axi4lite_slave.v
if errorlevel 1 ( echo [ERROR] Compile failed! & goto END )

echo [*] Running simulation...
vvp demo_udb_morph.out
echo.
echo [*] Opening GTKWave...
start gtkwave demo_udb_morph.vcd
echo.
echo  -------  What to observe  -------
echo  Signal: morph_trigger      ^| Pulse = MORPH requested
echo  Signal: rem_target_ctx     ^| 00=Acc 01=XOR 10=CRC 11=LFSR
echo  Signal: current_ctx        ^| Changes EXACTLY 1 cycle after trigger
echo  Signal: udb_io_out         ^| Output changes with each context
echo  Signal: morph_done         ^| Pulse when context switched
echo  -----------------------------------
goto END

:: ============================================================
:RUN_HSIOM
echo.
echo [*] Building Demo 2: HSIOM Self-Healing...
iverilog -g2005 -Wall -o demo_hsiom_failover.out ^
    demo_hsiom_failover.v ^
    ..\rtl\hsiom\hsiom_top.v ^
    ..\rtl\hsiom\hsiom_self_healing.v ^
    ..\rtl\hsiom\hsiom_cell.v ^
    ..\rtl\bus\axi4lite_slave.v
if errorlevel 1 ( echo [ERROR] Compile failed! & goto END )

echo [*] Running simulation...
vvp demo_hsiom_failover.out
echo.
echo [*] Opening GTKWave...
start gtkwave demo_hsiom_failover.vcd
echo.
echo  -------  What to observe  -------
echo  Signal: uart_tx_src        ^| UART data going into HSIOM
echo  Signal: pad_out            ^| Observe which pin carries TX signal
echo  Signal: hsiom_fault_event  ^| Goes HIGH when fault detected
echo  Signal: pad_in             ^| Stuck-at-0 = fault condition
echo  Pin[0].sig_uart            ^| Drops when primary fails
echo  Pin[1].sig_uart            ^| Activates as backup
echo  -----------------------------------
goto END

:: ============================================================
:RUN_UART
echo.
echo [*] Building Demo 3: UART TX...
iverilog -g2005 -Wall -o demo_uart_tx.out ^
    demo_uart_tx.v ^
    ..\rtl\uart\uart_top.v ^
    ..\rtl\uart\uart_reg.v ^
    ..\rtl\uart\UART_Tx.v ^
    ..\rtl\uart\UART_Rx.v ^
    ..\rtl\uart\Baud_gen.v ^
    ..\rtl\uart\tx_fifo.v ^
    ..\rtl\uart\rx_fifo.v ^
    ..\rtl\bus\axi4lite_slave.v
if errorlevel 1 ( echo [ERROR] Compile failed! & goto END )

echo [*] Running simulation...
vvp demo_uart_tx.out
echo.
echo [*] Opening GTKWave...
start gtkwave demo_uart_tx.vcd
echo.
echo  -------  What to observe  -------
echo  Signal: uart_tx            ^| Zoom in to see serial bit stream
echo  Signal: uart_tx_done       ^| Pulses after each byte completes
echo  Signal: uart_irq           ^| Fires per byte
echo  Tip: zoom into first 'M' = start bit(LOW), 8 data bits, stop(HIGH)
echo  -----------------------------------
goto END

:: ============================================================
:RUN_SNN
echo.
echo [*] Building Demo 4: SNN Gesture Classifier...
iverilog -g2005 -Wall -o demo_snn_gesture.out ^
    demo_snn_gesture.v ^
    ..\rtl\analog\analog_top.v ^
    ..\rtl\analog\analog_mux_bus.v ^
    ..\rtl\analog\idac_controller.v ^
    ..\rtl\analog\comparator_block.v ^
    ..\rtl\analog\neuromorphic_smartsense.v ^
    ..\rtl\bus\axi4lite_slave.v
if errorlevel 1 ( echo [ERROR] Compile failed! & goto END )

echo [*] Running simulation...
vvp demo_snn_gesture.out
echo.
echo [*] Opening GTKWave...
start gtkwave demo_snn_gesture.vcd
echo.
echo  -------  What to observe  -------
echo  Signal: pin_analog_in[7:0] ^| Voltage changes per gesture
echo  Signal: snn_spike          ^| Neuron fires when threshold crossed
echo  Signal: snn_anomaly_flag   ^| Goes HIGH on unknown pattern
echo  Gestures: TAP(short spike) SWIPE(ramp) HOLD(sustained) ROTATE(oscillate)
echo  -----------------------------------
goto END

:: ============================================================
:RUN_ALL
echo.
echo [*] Running ALL demos sequentially...
echo.

call :COMPILE_UDB
call :COMPILE_HSIOM
call :COMPILE_UART
call :COMPILE_SNN

echo.
echo [*] All simulations complete. Opening GTKWave for each...
echo     (Close each GTKWave window to proceed to the next)
echo.
start /wait gtkwave demo_udb_morph.vcd
start /wait gtkwave demo_hsiom_failover.vcd
start /wait gtkwave demo_uart_tx.vcd
start /wait gtkwave demo_snn_gesture.vcd
goto END

:: ---- Helper compile+run subroutines ----
:COMPILE_UDB
echo [*] Demo 1: UDB Morph...
iverilog -g2005 -o demo_udb_morph.out demo_udb_morph.v ^
    ..\rtl\udb\udb_top.v ..\rtl\udb\udb_morph_controller.v ^
    ..\rtl\udb\udb_datapath.v ..\rtl\udb\udb_macrocell.v ^
    ..\rtl\bus\axi4lite_slave.v 2>nul && vvp demo_udb_morph.out
goto :EOF

:COMPILE_HSIOM
echo [*] Demo 2: HSIOM Failover...
iverilog -g2005 -o demo_hsiom_failover.out demo_hsiom_failover.v ^
    ..\rtl\hsiom\hsiom_top.v ..\rtl\hsiom\hsiom_self_healing.v ^
    ..\rtl\hsiom\hsiom_cell.v ..\rtl\bus\axi4lite_slave.v 2>nul && vvp demo_hsiom_failover.out
goto :EOF

:COMPILE_UART
echo [*] Demo 3: UART TX...
iverilog -g2005 -o demo_uart_tx.out demo_uart_tx.v ^
    ..\rtl\uart\uart_top.v ..\rtl\uart\uart_reg.v ..\rtl\uart\UART_Tx.v ^
    ..\rtl\uart\UART_Rx.v ..\rtl\uart\Baud_gen.v ..\rtl\uart\tx_fifo.v ^
    ..\rtl\uart\rx_fifo.v ..\rtl\bus\axi4lite_slave.v 2>nul && vvp demo_uart_tx.out
goto :EOF

:COMPILE_SNN
echo [*] Demo 4: SNN Gesture...
iverilog -g2005 -o demo_snn_gesture.out demo_snn_gesture.v ^
    ..\rtl\analog\analog_top.v ..\rtl\analog\analog_mux_bus.v ^
    ..\rtl\analog\idac_controller.v ..\rtl\analog\comparator_block.v ^
    ..\rtl\analog\neuromorphic_smartsense.v ..\rtl\bus\axi4lite_slave.v 2>nul && vvp demo_snn_gesture.out
goto :EOF

:: ============================================================
:END
echo.
pause
