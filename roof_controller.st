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
    ulUpperLimit: UDINT; // Upper limit
    bReset: BOOL; // Reset state
END_VAR

VAR_OUTPUT // Output Variables
    bOpen: BOOL; // Open roof
    bClose: BOOL; // Close roof
    uiState: UDINT; // 0=Open / 1=Closing / 2=Closed / 3=Opening / 4=Reset / 5=Error
    uiCounterS1: UDINT; // Counter for Sensor 1
    uiCounterS2: UDINT; // Counter for Sensor 2
END_VAR

VAR // Local Variables
    uiInternalState: UDINT; // Internal state
    uiCounterS1Internal: UDINT; // Internal counter for Sensor 1
    uiCounterS2Internal: UDINT; // Internal counter for Sensor 2
    bInternalOpen: BOOL; // Internal open command
    bInternalClose: BOOL; // Internal close command
    bTriggerS1: BOOL; // Rising edge detection for Sensor 1
    bTriggerS2: BOOL; // Rising edge detection for Sensor 2
    tonTimeout: SYS.TON; // Timeout timer
    tonWait: SYS.TON; // Wait timer
    rUnevenValue: REAL; // Uneven measurement
END_VAR

// Initialize Timers
tonTimeout(T := T#5s);
tonWait(T := T#1s);

// Check for reset command
IF bReset THEN
    uiInternalState := 4;
END_IF;

// Finite State Machine (FSM)
CASE uiInternalState OF
    4: // Reset State
        uiInternalState := 0; // Reset to "Open"
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        tonTimeout.I := FALSE;
        tonWait.I := FALSE;
        uiCounterS1Internal := 0;
        uiCounterS2Internal := 0;

    0: // Open State
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        tonTimeout.I := FALSE;
        tonWait.I := bCloseCommand;

        IF bCloseCommand AND NOT bOpenCommand AND tonWait.Q THEN
            uiInternalState := 1;
        END_IF;

    1: // Closing State
        bInternalOpen := FALSE;
        bInternalClose := TRUE;
        tonTimeout.I := TRUE;
        tonWait.I := bOpenCommand;

        IF bSensor1 AND NOT bTriggerS1 THEN
            bTriggerS1 := TRUE;
            uiCounterS1Internal := uiCounterS1Internal + 1;
        END_IF;

        IF bSensor2 AND NOT bTriggerS2 THEN
            bTriggerS2 := TRUE;
            uiCounterS2Internal := uiCounterS2Internal + 1;
        END_IF;

        IF uiCounterS1Internal >= ulUpperLimit THEN
            uiInternalState := 2;
        END_IF;

        IF bOpenCommand AND NOT bCloseCommand AND tonWait.Q THEN
            uiInternalState := 3;
        END_IF;

        rUnevenValue := ABS(UDINT_TO_REAL(uiCounterS1Internal) - UDINT_TO_REAL(uiCounterS2Internal));
        IF rUnevenValue > 15 THEN
            uiInternalState := 5;
        END_IF;

    2: // Closed State
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        tonTimeout.I := FALSE;
        tonWait.I := bOpenCommand;

        IF bOpenCommand AND NOT bCloseCommand AND tonWait.Q THEN
            uiInternalState := 3;
        END_IF;

    3: // Opening State
        bInternalOpen := TRUE;
        bInternalClose := FALSE;
        tonTimeout.I := TRUE;
        tonWait.I := bCloseCommand;

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

        IF uiCounterS1Internal = 0 THEN
            uiInternalState := 0;
        END_IF;

        IF bCloseCommand AND NOT bOpenCommand AND tonWait.Q THEN
            uiInternalState := 1;
        END_IF;

        rUnevenValue := ABS(UDINT_TO_REAL(uiCounterS1Internal) - UDINT_TO_REAL(uiCounterS2Internal));
        IF rUnevenValue > 15 THEN
            uiInternalState := 5;
        END_IF;

    ELSE // Error States (Timeout or Uneven Detection)
        bInternalOpen := FALSE;
        bInternalClose := FALSE;
        tonTimeout.I := FALSE;
        tonWait.I := FALSE;
END_CASE;

// Rising Edge Detection
IF NOT bSensor1 AND bTriggerS1 THEN
    bTriggerS1 := TRUE;
END_IF;
IF NOT bSensor2 AND bTriggerS2 THEN
    bTriggerS2 := TRUE;
END_IF;

// Outputs
bOpen := bInternalOpen;
bClose := bInternalClose;
uiState := uiInternalState;
uiCounterS1 := uiCounterS1Internal;
uiCounterS2 := uiCounterS2Internal;

END_FUNCTION_BLOCK
