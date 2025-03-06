// ApplicationController - Application State Machine
// This function block manages the application state, handling user commands,
// wind conditions, and integrating with the RoofController.

FUNCTION_BLOCK ApplicationController

VAR_INPUT // Input Variables
    bOpenCommand: BOOL; // Open switch
    bCloseCommand: BOOL; // Close switch
    bSensor1: BOOL; // Sensor 1
    bSensor2: BOOL; // Sensor 2
    bWindEnable: BOOL; // Enable Wind level surveillance
    rWindlevel: REAL; // Wind level in [V]
    uiUpperLimit: UDINT; // Upper counter limit for close state
    uiWindLimit: REAL; // Wind level threshold
    uiTimeout: UDINT; // Timeout for roof control in [s]
    uiCounterReset: UDINT; // Reset value for the counters (S1 + S2)
    bReset: BOOL; // Reset state
END_VAR

VAR_OUTPUT // Output Variables
    bOpen: BOOL; // Open roof
    bClose: BOOL; // Close roof
    uiAppState: UDINT; // 0=Reset / 1=Normal / 2=Wind / 3=Error
    uiRoofState: UDINT; // 0=Open / 1=Closing / 2=Closed / 3=Opening / 4=Reset / 5=Error
    uiCounterS1: UDINT; // Counter for Sensor 1
    uiCounterS2: UDINT; // Counter for Sensor 2
    uiTimeoutCnt: UDINT; // Timeout counter value
END_VAR

VAR // Local Variables
    uiInternalAppState: UDINT; // Internal application state
    rfRoof: RoofController; // Roof controller instance
    tonWindOn: SYS.TON; // Wind Timeout timer (on)
    tonWindOff: SYS.TON; // Wind Timeout timer (off)
END_VAR

// Initialize Roof Controller
rfRoof(bSensor1 := bSensor1, bSensor2 := bSensor2, uiUpperLimit := uiUpperLimit, uiTimeout := uiTimeout, uiCounterReset := uiCounterReset);

// Initialize Timers
tonWindOn(T := T#5s);
tonWindOff(T := T#5s);

// Monitor Wind Level
tonWindOn.I := (rWindlevel >= uiWindLimit);
tonWindOff.I := (rWindlevel < uiWindLimit);

// Reset Condition
IF bReset THEN
    uiInternalAppState := 0; // Transition to Reset state
END_IF

// Finite State Machine (FSM)
CASE uiInternalAppState OF
    0: // Reset State
        rfRoof.bOpenCommand := FALSE;
        rfRoof.bCloseCommand := FALSE;
        rfRoof.bReset := TRUE;
        tonWindOn.I := FALSE;

        IF NOT bReset THEN
            uiInternalAppState := 1;
        END_IF

    1: // Normal Operation
        rfRoof.bReset := FALSE;
        rfRoof.bOpenCommand := bOpenCommand;
        rfRoof.bCloseCommand := bCloseCommand;

        // Transition to Wind State if wind condition persists and wind is enabled
        IF tonWindOn.Q AND bWindEnable THEN
            uiInternalAppState := 2;
        END_IF;

    2: // Wind Condition
        rfRoof.bReset := FALSE;
        rfRoof.bOpenCommand := TRUE;
        rfRoof.bCloseCommand := FALSE;

        // Return to Normal State once wind subsides and open command is given
        IF tonWindOff.Q AND bOpenCommand AND NOT bCloseCommand THEN
            uiInternalAppState := 1;
        END_IF;

    ELSE // Error Handling
        rfRoof.bReset := TRUE;
        tonWindOn.I := FALSE;
END_CASE;

// Outputs
uiAppState := uiInternalAppState;
bOpen := rfRoof.bOpen;
bClose := rfRoof.bClose;
uiRoofState := rfRoof.uiState;
uiCounterS1 := rfRoof.uiCounterS1;
uiCounterS2 := rfRoof.uiCounterS2;
uiTimeoutCnt := rfRoof.uiTimeoutCnt;

END_FUNCTION_BLOCK
