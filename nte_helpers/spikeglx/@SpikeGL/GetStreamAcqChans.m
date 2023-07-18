% chanCounts = GetStreamAcqChans( myobj, js, ip  )
%
%     For the selected substream, returns a vector of the
%     number of channels of each type that stream is acquiring.
%
%     js = 0: NI channels: {MN,MA,XA,DW}.
%     js = 1: OB channels: {XA,DW,SY}.
%     js = 2: IM channels: {AP,LF,SY}.
%
function [ret] = GetStreamAcqChans( s, js, ip )

    ret = str2num( DoQuery( s, sprintf( 'GETSTREAMACQCHANS %d %d', js, ip ) ) );
end
