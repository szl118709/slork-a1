// quarter note duration
0.4::second => dur playing_time;
0.3::second => dur waiting_time;

0.8 => float vel;
7 => int curr_left;
7 => int curr_right;
//  1. D:DF#AA           2          3. C:CEGC        4. G:DGBB        5. G4:DGCC        6. C9:CEGD    
[[50, 54, 57, 57], [55, 55, 55, 55], [48, 52, 55, 60], [50, 55, 59, 59], [50, 55, 60, 60], [48, 52, 55, 62]]@=> int chords[][];
4 => int numNotes;
6 => int numChan;
// patch
HevyMetl h[numChan][numNotes];
HevyMetl h_muted[numChan][numNotes];
// reverb
NRev r; 
.03 => dac.gain;
// reverb mix
0.05 => r.mix;

// FM operator envelope indices
[30,30,30,30] @=> int attacks[]; // [18,14,15,15] from patch
[31,31,31,31] @=> int decays[];  // [31,31,26,31] from patch
[14,14,14,10] @=> int sustains[]; // [15,15,13,15] from patch
[15,15,15,15] @=> int releases[]; // [8,8,8,8] from patch


[20,20,20,20] @=> int attacks_muted[]; // [18,14,15,15] from patch
[31,31,31,31] @=> int decays_muted[];  // [31,31,26,31] from patch
[5,5,5,5] @=> int sustains_muted[]; // [15,15,13,15] from patch
[20,20,20,20] @=> int releases_muted[]; // [8,8,8,8] from patch


// connect
for (int c; c < numChan; c++) {
for( int i; i < numNotes; i++ )
{
    h[c][i] => r => dac.chan(c);
    h_muted[c][i] => r => dac.chan(c);
    
    // LFO depth
    0.0 => h[c][i].lfoDepth;
    0.0 => h_muted[c][i].lfoDepth;
    
    // ops
    for( 0=>int op; op < numNotes; op++ )
    {
        h[c][i].opADSR( op,
        h[c][i].getFMTableTime(attacks[op]),
        h[c][i].getFMTableTime(decays[op]),
        h[c][i].getFMTableSusLevel(sustains[op]),
        h[c][i].getFMTableTime(releases[op]) );
    }
    for( 0=>int op; op < numNotes; op++ )
    {
        h_muted[c][i].opADSR( op,
        h_muted[c][i].getFMTableTime(attacks_muted[op]),
        h_muted[c][i].getFMTableTime(decays_muted[op]),
        h_muted[c][i].getFMTableSusLevel(sustains_muted[op]),
        h_muted[c][i].getFMTableTime(releases_muted[op]) );
    }
}
}


fun void playChord(int curr)
{
    if (curr != 2) {
        // set the pitches
        for( 0 => int i; i < numNotes; i++ ) {
            Std.mtof(chords[curr-1][i]) => h[curr-1][i].freq;
        }
        
        // note on
        for( 0 => int i; i < numNotes; i++ )
        { vel => h[curr-1][i].noteOn; }
        // sound
        0.7*(playing_time) => now;
        
        // note off
        for( 0 => int i; i < numNotes; i++ )
        { 1 => h[curr-1][i].noteOff; }
        // let ring
        0.3*(playing_time) => now;
    }
    else {
        // set the pitches
        for( 0 => int i; i < numNotes; i++ ) {
            Std.mtof(chords[curr-1][i]) => h_muted[curr-1][i].freq;
        }
        // note on
        for( 0 => int i; i < numNotes; i++ )
        { vel => h_muted[curr-1][i].noteOn; }
        // sound
        0.7*(playing_time) => now;
        
        // note off
        for( 0 => int i; i < numNotes; i++ )
        { 1 => h_muted[curr-1][i].noteOff; }
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
12001 => oscin.port;

// listen for "/wek/outputs" message with 2 floats coming in
oscin.addAddress( "/wek/outputs, ii" );
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 2 parameters...", "" >>>; 

// expecting 2 output dimensions
2 => int NUM_PARAMS;
int myParams[NUM_PARAMS];
Envelope genv[NUM_PARAMS];

// set the latest parameters as targets
// NOTE: we rely on map2sound() to actually interpret these parameters musically
fun void setParams( int params[] )
{
    // make sure we have enough
    if( params.size() >= NUM_PARAMS )
    {	
        // adjust the synthesis accordingly
        for( 0 => int i; i < NUM_PARAMS; i++ )
        {
            // get value
            params[i] => myParams[i];
        }

        myParams[0] => int new_left;
        myParams[1] => int new_right;

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
        int p[NUM_PARAMS];
        
        // wait for OSC message to arrive
        oscin => now;
        
        // 0 => float msg_count;
        // grab the last message from the queue. 
        while( oscin.recv(msg) ){
            for( int i; i < NUM_PARAMS; i++ )
            {
                if( msg.typetag.charAt(i) == 'i' ) // int
                {
                    msg.getInt(i) => p[i];
                    // 1 +=> msg_count;
                    // cherr <= p[i] <= " ";
                }              
            }         
        }
        
        if (p[0] > 0 && p[0] < 8){
            setParams( p );
            // waiting_time => now;
        }
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

fun void waitForKb() {
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
            kb_msg.ascii - 48 => curr;
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
}

// spork osc receiver loop
spork ~waitForEvent();
spork ~waitForKb();

// time loop to keep everything going
while( true ) 1::second => now;