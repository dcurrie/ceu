input error_t    Serial_startDone;
input error_t    Serial_sendDone;
input message_t* Serial_receive;


error_t serial_err;

define(`SERIAL_START', `// $1=timeout
loop do
    par/or do
        await $1;
    with
        serial_err = _Serial_start();
        if serial_err != 0 then
            emit serial_err;
        else
            serial_err = await Serial_startDone;
            if serial_err then
                emit serial_err;
            else
                break;
            end;
        end;
        await forever;
    end;
end
')

define(`SERIAL_SEND', `// $1=timeout ; $2=msg,$3=sz
loop do
    par/or do
        await $1;
    with
        serial_err = _Serial_send($2,$3);
        if serial_err != 0 then
            emit serial_err;
        else
            serial_err = await Serial_sendDone;
            if serial_err != 0 then
                emit serial_err;
            else
                break;
            end;
        end;
    end;
    await forever;
end
')
