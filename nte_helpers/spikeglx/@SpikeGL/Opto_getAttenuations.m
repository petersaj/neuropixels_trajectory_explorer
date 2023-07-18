% [site_atten_factors] = Opto_getAttenuations( myobj, ip, color )
%
%     Returns vector of 14 (double) site power attenuation factors.
%     ip:    imec probe index.
%     color: {0=blue, 1=red}.
%
function [ret] = Opto_getAttenuations( s, ip, color )

    ret = sscanf( ...
              DoQuery( s, ...
                  sprintf( 'OPTOGETATTENS %d %d', ip, color ) ), ...
              '%f' );
end
