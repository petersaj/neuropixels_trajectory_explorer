% list = GetProbeList( myobj )
%
%     Get string with format:
%     (probeID,nShanks,partNumber)()...
%     - A parenthesized entry for each selected probe.
%     - probeID: zero-based integer.
%     - nShanks: integer {1,4}.
%     - partNumber: string, e.g., NP1000.
%     - If no probes, return '()'.
%
function [list] = GetProbeList( s )

    list = DoQuery( s, 'GETPROBELIST' );
end
