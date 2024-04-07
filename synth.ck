// quarter note duration
0.4::second => dur playing_time;
0.3::second => dur waiting_time;

0.8 => float vel;
7 => int curr_left;
7 => int curr_right;
//  1. D:DF#AA           2          3. C:CEGC        4. G:DGBB        5. G4:DGCC        6. C9:CEGD    
[[50, 54, 57, 57], [55, 55, 55, 55], [48, 52, 55, 60], [50, 55, 59, 59], [50, 55, 60, 60], [48, 52, 55, 62]]@=> int chords[][];
4 => int numNotes;

// patch
HevyMetl h[numNotes];
// high pass (for echoes)
HPF hpf[numNotes];
// reverb
NRev r => dac; 
.8 => dac.gain;
// reverb mix
0.05 => r.mix;

// FM operator envelope indices
[30,30,30,30] @=> int attacks[]; // [18,14,15,15] from patch
[31,31,31,31] @=> int decays[];  // [31,31,26,31] from patch
[14,14,14,10] @=> int sustains[]; // [15,15,13,15] from patch
[15,15,15,15] @=> int releases[]; // [8,8,8,8] from patch

HevyMetl h_muted[numNotes];
[20,20,20,20] @=> int attacks_muted[]; // [18,14,15,15] from patch
[31,31,31,31] @=> int decays_muted[];  // [31,31,26,31] from patch
[5,5,5,5] @=> int sustains_muted[]; // [15,15,13,15] from patch
[20,20,20,20] @=> int releases_muted[]; // [8,8,8,8] from patch


// connect
for( int i; i < numNotes; i++ )
{
    h[i] => r;
    h_muted[i] => r;
    // set high pass
    600 => hpf[i].freq;
    
    // LFO depth
    0.0 => h[i].lfoDepth;
    0.0 => h_muted[i].lfoDepth;
    
    // ops
    for( 0=>int op; op < numNotes; op++ )
    {
        h[i].opADSR( op,
        h[i].getFMTableTime(attacks[op]),
        h[i].getFMTableTime(decays[op]),
        h[i].getFMTableSusLevel(sustains[op]),
        h[i].getFMTableTime(releases[op]) );
    }
    for( 0=>int op; op < numNotes; op++ )
    {
        h_muted[i].opADSR( op,
        h_muted[i].getFMTableTime(attacks_muted[op]),
        h_muted[i].getFMTableTime(decays_muted[op]),
        h_muted[i].getFMTableSusLevel(sustains_muted[op]),
        h_muted[i].getFMTableTime(releases_muted[op]) );
    }

}


fun void playChord(int curr)
{
    if (curr != 1) {
        // set the pitches
        for( 0 => int i; i < numNotes; i++ ) {
            Std.mtof(chords[curr][i]) => h[i].freq;
        }
        
        // note on
        for( 0 => int i; i < numNotes; i++ )
        { vel => h[i].noteOn; }
        // sound
        0.7*(playing_time) => now;
        
        // note off
        for( 0 => int i; i < numNotes; i++ )
        { 1 => h[i].noteOff; }
        // let ring
        0.3*(playing_time) => now;
    }
    else {
        // note on
        for( 0 => int i; i < numNotes; i++ )
        { vel => h_muted[i].noteOn; }
        // sound
        0.7*(playing_time) => now;
        
        // note off
        for( 0 => int i; i < numNotes; i++ )
        { 1 => h_muted[i].noteOff; }
        // let ring
        0.3*(playing_time) => now;
    }
}

// ----- OSC stuff -----
// create our OSC receiver
OscIn oscin;
// a thing to retrieve message contents
OscMsg msg;
// use port 12000 (default Wekinator output port)
12000 => oscin.port;

// listen for "/wek/output" message with 5 floats coming in
oscin.addAddress( "/wek/outputs, ff" );
// print
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 2 parameters...", "" >>>; 

// expecting 2 output dimensions
2 => int NUM_PARAMS;
float myParams[NUM_PARAMS];
Envelope genv[NUM_PARAMS];

// set the latest parameters as targets
// NOTE: we rely on map2sound() to actually interpret these parameters musically
fun void setParams( float params[] )
{
    // make sure we have enough
    if( params.size() >= NUM_PARAMS )
    {	
        // adjust the synthesis accordingly
        0.0 => float x;
        for( 0 => int i; i < NUM_PARAMS; i++ )
        {
            // get value
            params[i] => myParams[i];
        }

        myParams[0] $ int => int new_left;
        myParams[1] $ int => int new_right;

        0 => int play_left;
        0 => int play_right;
        if (new_left != curr_left && new_left != 7){
            1 => play_left;
        }
        if (new_right != curr_right && new_right != 7) {
            1 => play_right;
        }
        
        // mappings
        new_left => curr_left;
        new_right => curr_right;

        if (play_left) {
            spork ~ playChord(curr_left);
        }
        if (play_right) {
            spork ~ playChord(curr_right);
        }
        // 10::ms => now;
    }
}


fun void waitForEvent()
{
    
    // infinite event loop
    while( true )
    {
        // array to hold params
        float p[NUM_PARAMS];
        
        // wait for OSC message to arrive
        oscin => now;
        
        // 0 => float msg_count;
        // grab the last message from the queue. 
        while( oscin.recv(msg) ){
            for( int i; i < NUM_PARAMS; i++ )
            {
                if( msg.typetag.charAt(i) == 'f' ) // float
                {
                    msg.getFloat(i) => p[i];
                    // 1 +=> msg_count;
                    cherr <= p[i] <= " ";
                }
                else if( msg.typetag.charAt(i) == 'i' ) // int
                {
                    msg.getFloat(i) => p[i];
                    // 1 +=> msg_count;
                    cherr <= p[i] <= " ";
                }
                else if( msg.typetag.charAt(i) == 's' ) // string
                {
                    cherr <= msg.getString(i) <= " ";
                }                
            }         
        }
        
        setParams( p );
        // waiting_time => now;
        //1::second => now;
    }
}

Hid hi;
HidMsg kb_msg;

// which keyboard
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

// infinite event loop
while( true )
{
    // wait on event
    hi => now;
    0 => int curr;
    
    // get one or more messages
    while( hi.recv( kb_msg ) )
    {
        // check for action type
        if( kb_msg.isButtonDown() )
        {
            <<< "down:", kb_msg.which, "(code)", kb_msg.key, "(usb key)", kb_msg.ascii, "(ascii)" >>>;
            kb_msg.ascii - 49 => curr;
            if (curr >= 0 && curr <= 5) {
                spork ~ playChord(curr);
            }
        }
        else
        {
            //<<< "up:", msg.which, "(code)", msg.key, "(usb key)", msg.ascii, "(ascii)" >>>;
        }
        // waiting_time => now;
    }
}

// spork osc receiver loop
spork ~waitForEvent();

// time loop to keep everything going
while( true ) 1::second => now;