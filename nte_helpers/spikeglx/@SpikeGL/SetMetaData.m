% myobj = SetMetadata( myobj, metadata_struct )
%
%     If a run is in progress, set metadata to be added to the
%     next output file-set. Metadata must be in the form of a
%     struct of name/value pairs.
%
function [s] = SetMetadata( s, meta )

    if( ~isstruct( meta ) )
        error( 'SetMetaData: Argument must be a struct.' );
    end

    ChkConn( s );

    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( 'SETMETADATA\n' ) );
    ReceiveREADY( s, 'SETMETADATA' );

    names = fieldnames( meta );

    for i = 1:length( names )

        f = meta.(names{i});

        if( isnumeric( f ) && isscalar( f ) )
            line = sprintf( '%s=%g\n', names{i}, f );
        elseif( ischar( f ) )
            line = sprintf( '%s=%s\n', names{i}, f );
        else
            error( 'SetMetaData: Field %s must be numeric scalar or a string.', names{i} );
        end

        ok = CalinsNetMex( 'sendstring', s.handle, line );
    end

    % end with blank line
    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( '\n' ) );

    ReceiveOK( s, 'SETMETADATA' );
end
