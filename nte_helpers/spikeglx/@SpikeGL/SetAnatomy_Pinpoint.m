% myobj = SetAnatomy_Pinpoint( myobj, 'shankdat' )
%
%     Set anatomy data string with Pinpoint format:
%     [probe-id,shank-id](startpos,endpos,R,G,B,rgnname)(startpos,endpos,R,G,B,rgnname)…()
%        - probe-id: SpikeGLX logical probe id.
%        - shank-id: [0..n-shanks].
%        - startpos: region start in microns from tip.
%        - endpos:   region end in microns from tip.
%        - R,G,B:    region color as RGB, each [0..255].
%        - rgnname:  region name text.
%
function [s] = SetAnatomy_Pinpoint( s, shankdat )

    if( ~ischar( shankdat ) )
        error( 'SetAnatomy_Pinpoint: Argument must be a string.' );
    end

    DoSimpleCmd( s, sprintf( 'SETANATOMYPP %s', shankdat ) );
end
