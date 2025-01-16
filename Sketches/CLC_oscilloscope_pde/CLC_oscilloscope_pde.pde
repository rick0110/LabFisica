static boolean Debug = false;

import processing.serial.*;

boolean scope = true;
static final String SerialPort ="COM5"; 
//static final String SerialPort ="/dev/cu.usbserial-RCBB_4OK6T4";            // Change this to match your Arduino port
//static final String SerialPort ="COM4"; 

static final float fclk = 16e6;                    // Arduinos clock frequency

///* Commands to the Arduino board */
//static final char Reset = 'X';
//static final char ScopeMode = 'Y';
//static final char CounterMode = 'Z';
//static final char Channel1 = 'A';
//static final char ChannelMax = 'F';
//static final char TrigRising = 'w';
//static final char TrigFalling = 'x';
//static final char ContSweep = 'y';
//static final char SingleSweep = 'z';
//static final char TimeBaseMin = 'a';
//static final char TimeBaseMax = 't';
//static final char CounterBaseMin = 'G';
//static final char CounterBaseMax = 'U';

/* Text definitions */
static final String Sampling = "Sampling...";
static final String SampleFreqFmt = "[%1.1f Hz]";
static final String FreqFmt = "%1.2f Hz";
static final String PeriodFmt = "T = %dx (/%d)";

/* Trace definitions */
static final int MaxSample = 1000;
//static final int MaxSample = 500;
static final int SampleSize = 8;
static final int SampleMax = (1 << SampleSize) - 1;
static final int Channels = 6; //ChannelMax - Channel1 + 1;

/* Screen size */
static final int MaxX = 1000;
static final int MaxY = 550;
/* Trace dimensions */
static final int Width = 800;
static final int Height = 500;

/* Time base parameters class */
class TimebaseSet
{
  TimebaseSet(int f, float pwr, int s, float st)
  {
    factor = f;
    p10 = pwr;
    samples = s;
    sampleTime = st;
  }

  int factor;
  float p10;
  int samples;
  float sampleTime;
};

/* Class to execute a button action, used in conjunction with Button class */
abstract class ButtonAction
{
  public abstract void execute();

  public void setButton(Button b)
  {
    _button = b;
  }
  protected Button _button;
};

/* Class to represent a button with an associated action */
public class Button
{
  public Button(int centerx, int centery, int w, int h, String name, long col, ButtonAction action)
  {
    _cx = centerx;
    _cy = centery;
    _buttonWidth = w;
    _buttonHeight = h;
    text = name;
    red = (int) (col >> 16);
    green = (int) ((col >> 8) & 0xFF);
    blue = (int) (col & 0xFF);
    _action = action;
    if (_action != null)
    {
      _action.setButton(this);
    }
  }

  void enable(boolean on)
  {
    enabled = on;
  }

  /* Shows the button on the screen */
  public void draw()
  {
    if (enabled)
    {
      rectMode(CENTER);
      fill(red, green, blue);
      stroke(192, 192, 192);
      rect(_cx, _cy, _buttonWidth, _buttonHeight);
      textSize(20);
      fill(255, 255, 255);
      textAlign(CENTER, CENTER);
      text(text, _cx, _cy - 3);
    }
  }

  /* Checks if the button was clicked, executes the action if so */
  public void isClicked(int x, int y)
  {
    int bw = _buttonWidth / 2;
    int bh = _buttonHeight / 2;

    boolean result = enabled && ((x >= _cx - bw && x <= _cx + bw && y >= _cy - bh && y <= _cy + bh));

    if (Debug && result)
    {
      println(text + " clicked!");
    }
    if (result)
    {
      _action.execute();
    }
  }

  protected int _cx;
  protected int _cy;
  protected int _buttonWidth;
  protected int _buttonHeight;
  public int red;
  public int green;
  public int blue;
  public String text;
  protected ButtonAction _action;
  protected boolean enabled = true;
};

/* Class for check box buttons */
class CheckButton extends Button
{
  class Toggle extends ButtonAction
  {
    public Toggle(ButtonAction action)
    {
      _taction = action;
    }

    public void execute()
    {
      if (Debug)
      {
        println(text + " toggled");
      }
      _state = !_state;
      _taction.execute();
    }

    protected ButtonAction _taction;
  };

  public CheckButton(int centerx, int centery, int w, int h, String name, long col, ButtonAction action)
  {
    super(centerx, centery, w, h, name, col, null);

    _action = new Toggle(action);
  }

  /* Shows the button on the screen */
  public void draw()
  {
    rectMode(CENTER);
    if (_state)
    {
      fill(255 - red, 255 - green, 255 - blue);
    } else
    {
      fill(red, green, blue);
    }
    stroke(192, 192, 192);
    rect(_cx, _cy, _buttonWidth, _buttonHeight);
    textSize(14);
    fill(255, 255, 255);
    textAlign(LEFT, CENTER);
    text(text, _cx + _buttonWidth / 2 + 5, _cy - 3);
  }

  /* Returns the current state of the check box */
  public boolean getState()
  {
    return _state;
  }

  protected boolean _state = false;
};

/* Class for channel selection actions */
class ChAction extends ButtonAction
{
  ChAction(int ch)
  {
    _ch = ch;
  }

  public void execute()
  {
    if (_button.red == 0 & _button.green == 0 && _button.blue == 0)
    {
      setChannel(_ch);
    } else
    {
      showChannel(_ch);
    }
  }

  protected int _ch;
};

int currentChannel = 0;

TimebaseSet[] timebase = {
  new TimebaseSet(1, 0.0001, 475, 0.000003), // 0 com Interleaving x5
  new TimebaseSet(2, 0.0001, 140, 0.000015), 
  new TimebaseSet(5, 0.0001, 350, 0.000015), 
  new TimebaseSet(1, 0.001, 400, 0.000025), 
  new TimebaseSet(2, 0.001, 400, 0.000050), 
  new TimebaseSet(5, 0.001, 500, 0.000100), 
  new TimebaseSet(1, 0.01, 500, 0.000200), // 6 
  new TimebaseSet(2, 0.01, 500, 0.000400),  
  new TimebaseSet(5, 0.01, 500, 0.001), 
  new TimebaseSet(1, 0.1, 500, 0.002), 
  new TimebaseSet(2, 0.1, 500, 0.004), 
  new TimebaseSet(5, 0.1, 500, 0.01), 
  new TimebaseSet(1, 1, 500, 0.02), 
  new TimebaseSet(2, 1, 500, 0.04), 
  new TimebaseSet(5, 1, 1000, 0.05), 
  new TimebaseSet(1, 10, 1000, 0.1), 
  new TimebaseSet(2, 10, 1000, 0.2), 
  new TimebaseSet(5, 10, 1000, 0.5), 
  new TimebaseSet(1, 100, 1000, 1.0), 
  new TimebaseSet(2, 100, 1000, 2.0)
};

int timebaseIndex = 7;
float timediv;
float sens;                     /* mV/div */

int samples;
int channelSamples[] = { 0, 0, 0, 0, 0, 0 };
float sampleTime;
float sample[][] = new float[Channels][MaxSample];

// CLC = table for saving data
String[] dataline = new String[MaxSample];
String   namefile; // filename

long  channelColor[] = { 0xFFFF00, 0xFF00FF, 0x00FFFF, 0xFF0000, 0x00FF00, 0x0000FF };
float  channelSampleTime[] = { 0, 0, 0, 0, 0, 0 };
boolean channelOn[] = { false, false, false, false, false, false };
boolean channelVisible[] = { false, false, false, false, false, false };

float periodCount;
float divider = 1024.0;
float count = 0.0;
float countDigit = 1.0;
float frequency = 0.0;
boolean countingInd = false;
char periodCountInd = 'G'; //CounterBaseMin;


Serial port;
PFont f;

int set = 0;
int index = 0;

int x0 = 0, x1 = Width;
int y0 = 25, y1 = Height + y0;
int divx = Width / 10;
int divy = Height / 10;

float scalex;
float scaley;
float xcenter = (x0 + x1) / 2;
float ycenter = (y0 + y1) / 2;
float offset[] = { 0, 0, 0, 0, 0, 0 };
int sensFact[] = { 5, 5, 5, 5, 5, 5 };
int sens10[] = { 100, 100, 100, 100, 100, 100 };

boolean measuring = false;
//int flushingCountData = 0;
//boolean getChannelCount = false;

ArrayList<Button> button = new ArrayList();
CheckButton sweepButton;
CheckButton triggerButton;

void scale()
{
  scalex = Width / timediv / 10.0;
  scaley = Height / (sens / 1000.0) / 10.0;
}

float plotX(float time)
{
  return scalex * time;
}

float plotY(int channel, float voltage)
{
  return y1 - scaley * (voltage + offset[channel]);
}

/* Switch between scope and frequency counter mode */
void toggleMode()
{
  scope = !scope;
  //getChannelCount = scope;    // Wait for the number of channels reported by Arduino
  //flushingCountData = (scope ? 3 : 0);
  port.write(scope ? '*' : '#');
//  port.write(scope ? ScopeMode : CounterMode);
  port.clear();
  if (scope)
  {
    updateTimebase();
  } else
  {
    //scope = false;
    updatePeriodCount();
  }
}

/* Switch active channel for receiving samples */
void setChannel(int ch)
{
  channelOn[currentChannel] = false;
  currentChannel = ch;
  for (int i = 0; i < MaxSample; i++)
  {
    sample[currentChannel][i] = 0;
  }
  channelSamples[currentChannel] = samples;
  channelOn[currentChannel] = true;
  channelVisible[currentChannel] = true;
  sens = sensFact[currentChannel] * sens10[currentChannel];
  port.write((char) currentChannel + '1');  // Send channel switch command to Arduino
  //port.write((char) (currentChannel + Channel1));  // Send channel switch command to Arduino
  index = 0;
}

/* Toggle a channel's trace visibility */
void showChannel(int ch)
{
  channelVisible[ch] = !channelVisible[ch];
}

/* Handle start/stop button press */
void startStop()
{
  measuring = !measuring;
  index = 0;
  if (measuring && sweepButton.getState())
  {
    if (!Debug)
    {
      port.write('!');    // Send a reset command to Arduino
      //port.write(Reset);    // Send a reset command to Arduino
    }
  }
}
// CLC=savedata
void savedata()
{ String[] ssData = new String[channelSamples[currentChannel]];
  for(index=0;index<=channelSamples[currentChannel]-1;index++) {ssData[index]=dataline[index+1];}
  index=0;
  namefile="CH" + currentChannel + ".txt";
  saveStrings(namefile,ssData);
}

/* Toggle sweep mode between single and continuous */
void setSweep()
{
  if (!Debug)
  {
    port.write(sweepButton.getState() ? 'D' : 'C');
    //port.write(sweepButton.getState() ? SingleSweep : ContSweep);
  }
  index = 0;
}

/* Toggle trigger mode between rising and falling edge */
void setTriggerMode()
{
  if (!Debug)
  {
    port.write(triggerButton.getState() ? 'F' : 'E');
    //port.write(triggerButton.getState() ? TrigFalling : TrigRising);
  }
  index = 0;
}

/* Increase sensitivity */
void sensUp()
{
  if (sens > 10.0)
  {
    sensFact[currentChannel] /= 2;
    if (sensFact[currentChannel] == 0)
    {
      sens10[currentChannel] /= 10;
      sensFact[currentChannel] = 5;
    }
  }
}

/* Decrease sensitivity */
void sensDn()
{
  if (sens < 5000.0)
  {
    sensFact[currentChannel] *= 2;
    if (sensFact[currentChannel] == 4)
    {
      sensFact[currentChannel] = 5;
    }
    if (sensFact[currentChannel] >= 10)
    {
      sens10[currentChannel] *= 10;
      sensFact[currentChannel] = 1;
    }
  }
}

/* Update time base based on the value of timebaseIndex */
void updateTimebase()
{
  timediv = (float) timebase[timebaseIndex].factor * timebase[timebaseIndex].p10;
  samples = timebase[timebaseIndex].samples;
  sampleTime = timebase[timebaseIndex].sampleTime;
  channelSamples[currentChannel] = samples;
  scale();
  if (!Debug)
  {
    port.write((char) (timebaseIndex + 'a'));    // Send command to Arduino
    //port.write((char) (timebaseIndex + TimeBaseMin));    // Send command to Arduino
  }
  index = 0;
}

/* Increase time base (slower scan) */
void timeUp()
{
  if (scope)
  {
    if (timebaseIndex < 19)
    //if (timebaseIndex < TimeBaseMax - TimeBaseMin)
    {
      timebaseIndex++;
      updateTimebase();
    }
  } else
  {
    if (periodCountInd < 'U')
    //if (periodCountInd < CounterBaseMax)
    {
      periodCountInd++;
      updatePeriodCount();
    }
  }
}

/* Decrease time base (faster scan) */
void timeDn()
{
  if (scope)
  {
    if (timebaseIndex > 0)
    {
      timebaseIndex--;
      updateTimebase();
    }
  } else
  {
    if (periodCountInd > 'G')
    //if (periodCountInd > CounterBaseMin)
    {
      periodCountInd--;
      updatePeriodCount();
    }
  }
}

/* Update periods */
void updatePeriodCount()
{
  periodCount = 1.0;
  divider = 64.0;
  int s = periodCountInd - 'G';
  //int s = periodCountInd - CounterBaseMin;
  int p = s / 3;
  int d = 2 - (s % 3);
  for (int div = 0; div < d; div++)
  {
    divider *= 4.0;
  }
  for (int per = 0; per < p; per++)
  {
    periodCount *= 10.0;
  }
  port.write(periodCountInd);
  count = 0.0;
  countDigit = 1.0;
}

/* Initiate */
void setup()
{
  if (!Debug)
  {
    port = new Serial(this, SerialPort, 115200);
  } else
  {
    // For testing simulate a sine wave
    for (index = 0; index < MaxSample; index++)
    {
      sample[0][index] = 2.5*sin(2.0*PI*20.0*((float) (index * sampleTime / 1000.0)))+2.5;
    }
  }

  // Screen
  size(1000, 550);
  frameRate(50);
  background(0);
  f = createFont("System", 16);

  // Define buttons
  button.add(new Button(900, 40, 190, 30, "Scope / Count", 0x404040, new ButtonAction() { 
    public void execute() {
      toggleMode();
    }
  }
  ));
  button.add(new Button(900, 80, 190, 30, "Start / Stop", 0x404040, new ButtonAction() {
    public void execute() {
      startStop();
    }
  }
  ));
  // CLC=-SaveData Button
    button.add(new Button(900, 120, 190, 30, "Save Ch", 0x404040, new ButtonAction() {
    public void execute() {
      savedata();
    }
  }
  ));
  for (int ch = 0; ch < Channels; ch++)
  {
    button.add(new Button(825 + ch * 30, 205, 25, 25, "" + (char) ('1' + ch), 0, new ChAction(ch)));
  }
  for (int ch = 0; ch < Channels; ch++)
  {
    button.add(new Button(825 + ch * 30, 240, 25, 25, "", channelColor[ch], new ChAction(ch)));
  }
  button.add(sweepButton = new CheckButton(825, 280, 20, 20, "Single Sweep", 0x000000, new ButtonAction() {
    public void execute() {
      setSweep();
    }
  }
  ));
  button.add(triggerButton = new CheckButton(825, 315, 20, 20, "Trigger on falling edge", 0x000000, new ButtonAction() {
    public void execute() {
      setTriggerMode();
    }
  }
  ));
  button.add(new Button(850, 380, 90, 50, "Sens -", 0x404040, new ButtonAction() {
    public void execute() {
      sensDn();
    }
  }
  ));
  button.add(new Button(950, 380, 90, 50, "Sens +", 0x404040, new ButtonAction() {
    public void execute() {
      sensUp();
    }
  }
  ));
  button.add(new Button(850, 440, 90, 50, "Offset -", 0x404040, new ButtonAction() {
    public void execute()
    {
      if (offset[currentChannel] > -15.0)
      {
        offset[currentChannel] -= 0.5;
      }
    }
  }
  ));
  button.add(new Button(950, 440, 90, 50, "Offset +", 0x404040, new ButtonAction() {
    public void execute()
    {
      if (offset[currentChannel] < 15.0)
      {
        offset[currentChannel] += 0.5;
      }
    }
  }
  ));
  button.add(new Button(850, 500, 90, 50, "Time -", 0x404040, new ButtonAction() {
    public void execute() {
      timeDn();
    }
  }
  ));
  button.add(new Button(950, 500, 90, 50, "Time +", 0x404040, new ButtonAction() {
    public void execute() {
      timeUp();
    }
  }
  ));

  // Set initial configuration of the scope (matches Arduino defaults)
  updateTimebase();
  updatePeriodCount();
  setChannel(currentChannel);
  startStop();
}

void draw()
{
  clear();

  if (measuring & scope)
  {
    textSize(16);
    fill(255, 255, 255);
    text(Sampling, 900, 147);
    text(String.format(SampleFreqFmt, 1.0 / sampleTime), 900, 170);
  }

  /* Gridlines */
  stroke(0, 128, 0);

  /* Vertical */
  for (int x = 0; x <= x1; x += divx)
  {
    line(x, y1, x, y0);
  }
  /* Horizontal */
  for (int y = y0; y <= y1; y += divy)
  {
    line(x0, y, x1, y);
  }

  /* Emphasize horizontal and vertical center lines */
  stroke(0, 255, 0);
  line(xcenter, y0, xcenter, y1);
  line(x0, ycenter, x1, ycenter);

  /* Show all buttons */
  for (int b = 0; b < button.size(); b++)
  {
    button.get(b).draw();
  }

  /* Show active channel */
  stroke(255, 0, 0);
  noFill();
  rect(825 + currentChannel * 30, 205, 25, 25);

  /* Scaling info text */
  textSize(20);
  fill(255, 255, 255);
  textAlign(LEFT, CENTER);
  textFont(f);
  fill(0, 255, 0);
  sens = sensFact[currentChannel] * sens10[currentChannel];
  text(String.format("%d%cV/div", (int) (sens > 999 ? sens / 1000 : sens), 
    sens < 1000.0 ? 'm' : '\0'), x0 + 4, y0 + divy / 4);
  text(String.format("Offset: %+1.1fV", offset[currentChannel]), x0 + 4, y0 + 3 * divy / 4);

  int tb = (int) (timediv);
  char unit = ' ';

  if (timediv < 0.001)
  {
    tb = (int) (timediv * 1000000.0 + 0.5);
    unit = 'u';
  } else if (timediv < 1.0)
  {
    tb = (int) (timediv * 1000.0 + 0.5);
    unit = 'm';
  }

  textAlign(CENTER, CENTER);
  text(String.format("%d%cs/div", tb, unit), x0 + 19 * divx / 2, y0 + 19 * divy / 2);

  if (scope)
  {
    /* Display the sample traces */

    for (int ch = 0; ch < Channels; ch++)
    {
      if (channelVisible[ch])
      {
        sens = sensFact[ch] * sens10[ch];
        scale();
        float prevx = plotX(0.0);
        float prevy = plotY(ch, sample[ch][0]);
        long c = channelColor[ch];

        prevy = max(prevy, y0);
        prevy = min(prevy, y1);

        stroke(c >> 16, (c >> 8) & 0xFF, c & 0xFF);

        for (int i = 1; i < channelSamples[currentChannel] && prevx < x1; i++)
        {
          float x = plotX(i * sampleTime);
          float y = plotY(ch, sample[ch][i]);
          if (y <= y1 && y >= y0)
          {
            line(prevx, prevy, x, y);
            prevx = x;
            prevy = y;
          }
        }
      }
    }
  } else
  {
    rectMode(CENTER);
    stroke(255, 255, 255);
    fill(0, 0, 0);
    rect((x0 + x1) / 2, ycenter, 4 * divx, 2 * divy);

    if (countingInd)
    {
      fill(255, 0, 0);
      rect(xcenter - 7 * divx / 4, ycenter - 3 * divy / 4, 20, 20);
    }

    textAlign(CENTER, CENTER);
    textSize(30);
    fill(255, 255, 255);
    text(String.format(FreqFmt, frequency), xcenter, ycenter - divy / 4);
    textSize(18);
    text(String.format(PeriodFmt, (int) periodCount, (int) divider), xcenter, ycenter + divy / 2);
  }
  sens = sensFact[currentChannel] * sens10[currentChannel];
}

/* Handle button clicks */
void mouseClicked()
{
  int mx = mouseX; 
  int my = mouseY;

  for (int b = 0; b < button.size(); b++)
  {
    button.get(b).isClicked(mx, my);
  }
}

void keyPressed()
{
  if (!Character.isLetter(key))
  {
    port.write(key);
  }
}

/* Handle incoming sample data from Arduino */
void serialEvent(Serial port)
{
  int s;
  float v;

  try
  {
    if (port.available() != 0)
    {
      s = port.read();
      v = s;
      if (s == 0xFF)    // End-of-sweep indicator
      {
        if (scope)
        {
          //if (flushingCountData > 0)
          //{
          //  flushingCountData--;
          //}
          index = 0;
        } else
        {
          if (countDigit >= 4294967296.0)
          {
            if (count > 0)
            {
              frequency = fclk * periodCount / (count * divider) ;
            }
            count = 0.0;
            countDigit = 1;
            countingInd = !countingInd;
          } else
          {
            count += (v * countDigit);
            countDigit *= 256;
          }
        }
      } else
      {
        if (scope)
        {
          //if (getChannelCount)
          //{
          //  if (flushingCountData == 0)            // If 3 consecutive 0xFF found, number of channels follows 
          //  {
          //    getChannelCount = false;
          //    s -= '0';
          //    for (int i = 0; i < 6; i++)
          //    {
          //      button.get(2 + i).enable(i < s);
          //      button.get(8 + i).enable(i < s);
          //    }
          //  } else
          //  {
          //    flushingCountData = 3;
          //  }
          //}
          if (measuring)
          {
            sample[currentChannel][index++] = map(s, 0.0, 255.0, 0.0, 5.0);
 //           dataline[index] = index + "\t" + s; // CLC=for saving data: index,s(0,255)
            dataline[index] = index*sampleTime + "\t" + s*10/sens; // CLC=(mV)for saving data 
            if (index >= channelSamples[currentChannel])
            {
              index = 0;
              if (sweepButton.getState())
              {
                measuring = false;
              }
            }
          }
        } else
        {
          count += (v * countDigit);
          countDigit *= 256;
        }
      }
    }
  }

  catch(RuntimeException e)
  {
    e.printStackTrace();
  }
}
