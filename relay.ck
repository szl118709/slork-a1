//-----------------------------------------------------------------------------
// name: gametra.ck
// desc: gametrak boilerplate code;
//       prints 6 axes of the gametrak tethers + foot pedal button;
//       a helpful starting point for mapping gametrak
//
// author: Ge Wang (ge@ccrma.stanford.edu)
// date: summer 2014
//-----------------------------------------------------------------------------

// z axis deadzone
0 => float DEADZONE;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects
Hid trak;
HidMsg msg;

// open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();

// print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}

// gametrack
GameTrak gt;

// spork control
spork ~ gametrak();

// destination host name
"localhost" => string hostname;
// destination port number: 6448 is Wekinator default
6448 => int port;
// our OSC sender (to Wekinator)
OscOut xmit;
// aim the transmitter at destination
xmit.dest( hostname, port );

// main loop
while( true )
{
    // print 6 continuous axes -- XYZ values for left and right
    //<<< "axes:", gt.axis[0],gt.axis[1],gt.axis[2],gt.axis[3],gt.axis[4],gt.axis[5] >>>;
    
    // also can map gametrak input to audio parameters around here
    // note: gt.lastAxis[0]...gt.lastAxis[5] hold the previous XYZ values
    send2wek();
    
    // advance time
    100::ms => now;
}

// reformat and send what we want to Wekinator
fun void send2wek()
{
    // start the message...
    xmit.start( "/wek/inputs" );
    
    // print
    //cherr <= "  *** SENDING: \"/wek/inputs/\": ";
    //for (int i; i < gt.axis.size(); i++) {
    //    cherr <= gt.axis[i] <= " ";
    //}
    //cherr <= IO.newline();
    
    // add each for sending
    for (int i; i < gt.axis.size(); i++) {
        gt.axis[i] => xmit.add;
    }
    
    // send it
    xmit.send();
}

// gametrack handling
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                <<< "button", msg.which, "down" >>>;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}