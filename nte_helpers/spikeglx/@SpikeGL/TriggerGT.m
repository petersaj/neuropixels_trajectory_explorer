% myobj = TriggerGT( myobj, g, t )
%
%     Using standard auto-naming, set both the gate (g) and
%     trigger (t) levels that control file writing.
%       -1 = no change.
%        0 = set low.
%        1 = increment and set high.
%     E.g., triggerGT( -1, 1 ) = same g, increment t, start writing.
%
%     - TriggerGT only affects the 'Remote controlled' gate type and/or
%     the 'Remote controlled' trigger type.
%     - The 'Enable Recording' button, when shown, is a master override
%     switch. TriggerGT is blocked until you click the button or call
%     SetRecordingEnable.
%
function [s] = TriggerGT( s, g, t )

    DoSimpleCmd( s, sprintf( 'TRIGGERGT %d %d', g, t ) );
end
