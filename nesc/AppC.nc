typedef int32_t  s32;
typedef uint32_t u32;
typedef int16_t  s16;
typedef uint16_t u16;
typedef int8_t   s8;
typedef uint8_t  u8;

typedef u32 tceu_time;
typedef u16 tceu_reg;
typedef u16 tceu_gte;
typedef u16 tceu_trg;
typedef u16 tceu_lbl;

/*
// increases code size
#define ceu_out_pending()   (!call Scheduler.isEmpty() || !q_isEmpty(&Q_EXTS))
#define ceu_out_timer(ms)   call Timer.startOneShot(ms)

//#include <assert.h>
//#define ASSERT(x,v) if (!(x)) { call Leds.set(v); EXIT_ok=1; }
#define ASSERT(x,v)
*/

#include "IO.h"
#include "Timer.h"

module AppC @safe()
{
    uses interface Boot;
    uses interface Scheduler;
    uses interface Timer<TMilli> as Timer;
    uses interface Timer<TMilli> as TimerAsync;

#ifdef IO_LEDS
    uses interface Leds;
#endif
#ifdef IO_SOUNDER
    uses interface Mts300Sounder as Sounder;
#endif
#ifdef IO_PHOTO
    uses interface Read<uint16_t> as Photo;
#endif
#ifdef IO_RADIO
    uses interface AMSend       as RadioSend[am_id_t id];
    uses interface Receive      as RadioReceive[am_id_t id];
    uses interface Packet       as RadioPacket;
    uses interface AMPacket     as RadioAMPacket;
    uses interface SplitControl as RadioControl;
#endif
#ifdef IO_SERIAL
    uses interface AMSend       as SerialSend[am_id_t id];
    uses interface Receive      as SerialReceive[am_id_t id];
    uses interface Packet       as SerialPacket;
    uses interface AMPacket     as SerialAMPacket;
    uses interface SplitControl as SerialControl;
#endif
}

implementation
{
    int RET = 0;
    #include "C2nesc.c"
    #include "_ceu_code.tmp"

    event void Boot.booted ()
    {
        ceu_go_init(NULL, call Timer.getNow());
#ifdef IO_Start
        ceu_go_event(NULL, IO_Start, NULL);
#endif

        // TODO: periodic nunca deixaria TOSSched queue vazia
#ifndef ceu_out_timer
        call Timer.startOneShot(10);
#endif
#if N_ASYNCS > 0
        call TimerAsync.startOneShot(10);
#endif
    }
    
    event void Timer.fired ()
    {
        ceu_go_time(NULL, call Timer.getNow());
#ifndef ceu_out_timer
        call Timer.startOneShot(10);
#endif
    }

    event void TimerAsync.fired ()
    {
#if N_ASYNCS > 0
        call TimerAsync.startOneShot(10);
        ceu_go_async(NULL,NULL);
#endif
    }

#ifdef IO_PHOTO
    event void Photo.readDone(error_t err, uint16_t val) {
        int v = val;
        ceu_go_event(NULL, IO_Photo_readDone, &v);
    }
#endif // IO_PHOTO

#ifdef IO_RADIO
    event void RadioControl.startDone (error_t err) {
#ifdef IO_Radio_startDone
        int v = err;
        ceu_go_event(NULL, IO_Radio_startDone, &v);
#endif
    }

    event void RadioControl.stopDone (error_t err) {
#ifdef IO_Radio_stopDone
        int v = err;
        ceu_go_event(NULL, IO_Radio_stopDone, &v);
#endif
    }

    event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t err)
    //event void RadioSend.sendDone(message_t* msg, error_t err)
    {
        //dbg("APP", "sendDone: %d %d\n", data[0], data[1]);
#ifdef IO_Radio_sendDone
        int v = err;
        ceu_go_event(NULL, IO_Radio_sendDone, &v);
#endif
    }

    event message_t* RadioReceive.receive[am_id_t id]
        (message_t* msg, void* payload, uint8_t nbytes)
    {
#ifdef IO_Radio_receive
        void* ptr = msg;
        ceu_go_event(NULL, IO_Radio_receive, &ptr);
#endif
        return msg;
    }
#endif // IO_RADIO

#ifdef IO_SERIAL
    event void SerialControl.startDone (error_t err)
    {
#ifdef IO_Serial_startDone
        int v = err;
        ceu_go_event(NULL, IO_Serial_startDone, &v);
#endif
    }

    event void SerialControl.stopDone (error_t err)
    {
#ifdef IO_Serial_stopDone
        int v = err;
        ceu_go_event(NULL, IO_Serial_stopDone, &v);
#endif
    }

    event void SerialSend.sendDone[am_id_t id](message_t* msg, error_t err)
    {
        //dbg("APP", "sendDone: %d %d\n", data[0], data[1]);
#ifdef IO_Serial_sendDone
        int v = err;
        ceu_go_event(NULL, IO_Serial_sendDone, &v);
#endif
    }
    
    event message_t* SerialReceive.receive[am_id_t id]
        (message_t* msg, void* payload, uint8_t nbytes)
    {
#ifdef IO_Serial_receive
        void* ptr = msg;
        ceu_go_event(NULL, IO_Serial_receive, &ptr);
#endif
        return msg;
    }

#endif // IO_SERIAL

}
