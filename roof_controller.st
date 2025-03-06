// RoofController - Roof Control State Machine
// This function block controls the state of a roof opening/closing system.
// It manages separate commands for opening and closing, monitors sensors, and ensures safety through error detection.
// The system includes timeouts and uneven movement detection.

FUNCTION_BLOCK RoofController // Roof controlling state machine

VAR_INPUT // Input Variables
    bOpenCommand: BOOL; // Command to open the roof
    bCloseCommand: BOOL; // Command to close the roof
    bSensor1: BOOL; // Sensor 1
    bSensor2: BOOL; // Sensor 2
    uiUpperLimit: UDINT; // Upper limit
    uiTimeout: UDINT; // Timeout for running motor [s]
    uiCounterReset: UDINT; // Reset value for the counters (S1 + S2)
    bReset: BOOL; // Reset state
END_VAR

VAR_OUTPUT // Output Variables
    bOpen: BOOL; // Open roof
    bClose: BOOL; // Close roof
    uiState: UDINT; // 0=Open / 1=Closing / 2=Closed / 3=Opening / 4=Reset / 5=Error / 7=Switching
    uiCounterS1: UDINT; // Counter for Sensor 1
    uiCounterS2: UDINT; // Counter for Sensor 2
    uiTimeoutCnt: UDINT; // Timeout counter value
END_VAR

VAR // Local Variables
    uiInternalState: UDINT; // Internal state
    uiCounterS1Internal: UDINT; // Internal counter for Sensor 1
    uiCounterS2Internal: UDINT; // Internal counter for Sensor 2
    bInternalOpen: BOOL; // Internal open command
    bInternalClose: BOOL; // Internal close command
    bTriggerS1: BOOL; // Rising edge detection for Sensor 1
    bTriggerS2: BOOL; // Rising edge detection for Sensor 2
    tonWait: SYS.TON; // Wait timer
    tStart: TIME; // Start time of opening/closeing state
    uiTimeoutCntInternal: UDINT; // Internal timeout counter value
    rUnevenValue: REAL; // Uneven measurement
END_VAR

// Initialize Timers
tonWait(T := T#1s);

// Check for reset command
IF bReset THEN
    uiInternalState := 4;
END_IF;

// Finite State Machine (FSM)
CASE uiInternalState OF
    4: // Reset State
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        tonWait.I := FALSE;
        uiTimeoutCntInternal := 0;

        IF NOT bReset THEN
            uiInternalState := 7;
            uiCounterS1Internal := uiCounterReset;
            uiCounterS2Internal := uiCounterReset;
        END_IF

    0: // Open State
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        uiTimeoutCntInternal := 0;
        tonWait.I := bCloseCommand;

        IF bCloseCommand AND NOT bOpenCommand AND tonWait.Q THEN
            uiInternalState := 1;
            tStart := get_time();
        END_IF;

    1: // Closing State
        bInternalOpen := FALSE;
        bInternalClose := TRUE;
        tonWait.I := FALSE;
        uiTimeoutCntInternal := (TIME_TO_UDINT(get_time()) - TIME_TO_UDINT(tStart)) / 1000;

        IF bSensor1 AND NOT bTriggerS1 THEN
            bTriggerS1 := TRUE;
            uiCounterS1Internal := uiCounterS1Internal + 1;
        END_IF;

        IF bSensor2 AND NOT bTriggerS2 THEN
            bTriggerS2 := TRUE;
            uiCounterS2Internal := uiCounterS2Internal + 1;
        END_IF;

        IF uiTimeoutCntInternal >= uiTimeout THEN
            uiInternalState := 5;
        END_IF

        IF uiCounterS1Internal >= uiUpperLimit THEN
            uiInternalState := 2;
        END_IF;

        IF bOpenCommand AND NOT bCloseCommand THEN
            uiInternalState := 7;
        END_IF;

        rUnevenValue := ABS(UDINT_TO_REAL(uiCounterS1Internal) - UDINT_TO_REAL(uiCounterS2Internal));
        IF rUnevenValue > 15 THEN
            uiInternalState := 6;
        END_IF;

    2: // Closed State
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        uiCounterS1Internal := uiUpperLimit;
        uiCounterS2Internal := uiUpperLimit;
        uiTimeoutCntInternal := 0;
        tonWait.I := bOpenCommand;

        IF bOpenCommand AND NOT bCloseCommand AND tonWait.Q THEN
            uiInternalState := 3;
            tStart := get_time();
        END_IF;

    3: // Opening State
        bInternalOpen := TRUE;
        bInternalClose := FALSE;
        uiTimeoutCntInternal := (TIME_TO_UDINT(get_time()) - TIME_TO_UDINT(tStart)) / 1000;
        tonWait.I := FALSE;

        IF bSensor1 AND NOT bTriggerS1 THEN
            bTriggerS1 := TRUE;
            IF uiCounterS1Internal > 0 THEN
                uiCounterS1Internal := uiCounterS1Internal - 1;
            END_IF;
        END_IF;

        IF bSensor2 AND NOT bTriggerS2 THEN
            bTriggerS2 := TRUE;
            IF uiCounterS2Internal > 0 THEN
                uiCounterS2Internal := uiCounterS2Internal - 1;
            END_IF;
        END_IF;

        IF uiTimeoutCntInternal >= uiTimeout THEN
            uiInternalState := 5;
        END_IF

        IF uiCounterS1Internal = 0 THEN
            uiInternalState := 0;
        END_IF;

        IF bCloseCommand AND NOT bOpenCommand THEN
            uiInternalState := 7;
        END_IF;

        rUnevenValue := ABS(UDINT_TO_REAL(uiCounterS1Internal) - UDINT_TO_REAL(uiCounterS2Internal));
        IF rUnevenValue > 15 THEN
            uiInternalState := 6;
        END_IF;

    7: // Switching State
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        uiTimeoutCntInternal := 0;
        tonWait.I := (bCloseCommand OR bOpenCommand);
        tStart := get_time();


        IF tonWait.Q AND bOpenCommand THEN
            uiInternalState := 3;
        END_IF;

        IF tonWait.Q AND bCloseCommand THEN
            uiInternalState := 1;
        END_IF;

        IF uiCounterS1Internal >= uiUpperLimit AND bCloseCommand THEN
            uiInternalState := 2;
        END_IF

        IF uiCounterS1Internal = 0 AND bOpenCommand THEN
            uiInternalState := 0;
        END_IF


    ELSE // Error States (Timeout or Uneven Detection)
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
END_CASE;

// Reset Edge Detection
IF NOT bSensor1 AND bTriggerS1 THEN
    bTriggerS1 := FALSE;
END_IF;
IF NOT bSensor2 AND bTriggerS2 THEN
    bTriggerS2 := FALSE;
END_IF;

// Outputs
bOpen := bInternalOpen;
bClose := bInternalClose;
uiState := uiInternalState;
uiCounterS1 := uiCounterS1Internal;
uiCounterS2 := uiCounterS2Internal;
uiTimeoutCnt := uiTimeoutCntInternal;

END_FUNCTION_BLOCK
