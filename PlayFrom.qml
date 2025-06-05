import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import MuseScore
import Muse.Ui
import Muse.UiComponents

//=============================================================================
// PlayFrom v1.0
// MuseScore 4.x  
//
// A plugin to add some basic drumset patterns 
//
// (C) 2025 Phil Kan 
// PitDad Music. All Rights Reserved. 
//
//=============================================================================

MuseScore {
  version: "1.0"
  title: "Play From";
  categoryCode:"PitDad Tools"
  description: "Play From v1.0 for MuseScore 4.4+  Play from predefined markers in the score"
  thumbnailName: "PlayFromIcon.png";
  pluginType: "dialog"
  
//=============================================================================
// Main UI Definition starts 
  SystemPalette { id: palette; colorGroup: SystemPalette.Active }
  
  property var lastCursorPosition: {
    "isRange": false, 
    "element": 0,
    "startTick": 0,
    "endTick": 0,
    "startStaff": 0, 
    "endStaff": 0
  };
  
  property var rehearsalMarks: [];
  property var leadInModel: [
    { "text": "--", "value": 0 },
    { "text": "1 bar", "value": 1 },
    { "text": "2 bars", "value": 2 }
  ]
  
//=============================================================================

  implicitHeight: 220;
  implicitWidth:  250;
  
  ButtonGroup { id: radioGroup }

  ColumnLayout 
  {
    anchors.fill: parent
    id: playFromMainLayout
    spacing: 5
    anchors.margins: 10
    
    StyledTextLabel {
      id: titleLabel
      text: "Play From:"
      font.bold: true           
    }
    
    RadioButton {
      id: currentPositionButton
      text: "Current Position"
      ButtonGroup.group: radioGroup
    }
    
    RadioButton {
      id: previousPositionButton
      text: "Previous Position"
      checked: false
      ButtonGroup.group: radioGroup
    }

    // rehearsalMarks
    RowLayout {
      id: rehearsalMarkRow
      spacing: 4
      
      RadioButton {
        id: rehearsalMarkButton
        text: "Rehearsal Mark"
        checked: false
        ButtonGroup.group: radioGroup
      }
      
      StyledDropdown {
        id: rehearsalMarksCombo
        Layout.fillWidth: true

        model: rehearsalMarks
        currentIndex: 0

        onActivated: function(index, value) {
          rehearsalMarkButton.checked = true
          currentIndex = index
        }
      }
    }
    
    // Lead In options
    RowLayout {
      id: leadInByRow
      spacing: 4
      
      StyledTextLabel {
        id: leadInByLabel
        text: "Lead in: "
      }
      
      StyledDropdown {
        id: leadInCombo
        Layout.fillWidth: true

        model: leadInModel
        currentIndex: 0

        onActivated: function(index, value) {
          currentIndex = index
        }
      }
    }
    
    // Details --- Apply / About
    Row {
      id: playAboutButtonsRow
      spacing: 5
      anchors.bottom: playFromMainLayout.bottom

      Item 
      {
        id: bufferItem
        Layout.fillWidth: true
      }

      FlatButton 
      {
        id: playButton
        text: "Play"
        accentButton: true        
        isNarrow: true   
        focus:true
        onClicked: play()

        Keys.onReturnPressed: {
          clicked()
          event.accepted = true
        }        
      }

      FlatButton 
      {
        id: aboutButton
        text: "About"  
        isNarrow: true      
        onClicked: aboutDialog.show()
      }
    }
  }
      
//=============================================================================

  property string aboutDialogText: "
    <h3>Play From</h3>
    <p>
    Play from predefined rehearsal marks & double bar lines. 
    </p>
    <p>
    MIT License <br>
    (C) 2025 Phil Kan <br>
    PitDad Music. All Rights Reserved. 
    </p>
    <p>PitDadPhil@gmail.com</p>
    <p>
    Help on <a href='https://github.com/philxan/PlayFrom/blob/main/README.md'>Github</a>
    </p>
  "
  
  property string linkText: "https://github.com/philxan/PlayFrom/blob/main/README.md"
  

  StyledDialogView {
    id: aboutDialog
    
    title: "About Play From"
    contentHeight: 275
    contentWidth: 350 
    
    ColumnLayout {
      anchors.fill: parent
        
      StyledTextLabel {
        id: aboutTextControl
        text: aboutDialogText
        anchors.fill: parent
        anchors.margins: 20
        onLinkActivated: Qt.openUrlExternally(linkText)
        wrapMode: Text.Wrap
        textFormat: Text.StyledText
        
        MouseArea 
        {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton // we don't want to eat clicks on the Text
          cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
      }
    }
  }

//=============================================================================

  MessageDialog 
  {
    id: infoDialog
    visible: false
    title: "DrumSet Patterns"
    text: "someTextHere"
    onAccepted: {
      close();
    }
  }

  function showMessage(message)
  {
    infoDialog.text = message;
    infoDialog.open();
  }
  
  function showMessageArgs(...args)
  {
    var message = "";
    for (var argNum = 0; argNum < args.length; argNum++)
    {
      message = message + args[argNum] + "\n";
    }
    
    showMessage(message);
  }
  
//=============================================================================

  function findRehearsalMarks() 
  {
    rehearsalMarks = [];
    
    rehearsalMarks.push({text: "Start ", value: 0 });
    
    var cursor = curScore.newCursor();
    cursor.rewind(Cursor.SCORE_END);
    var endTick = cursor.tick;
    
    // this happens when the selection includes  the last measure of the score.
    // rewind(Cursor.SELECTION_END) goes behind the last segment (where there's none) and sets tick=0
    if (cursor.tick == 0) {
      endTick = curScore.lastSegment.tick;
    }
    
    cursor.rewind(Cursor.SCORE_START);
  
    while (cursor.segment && (cursor.tick < endTick)) {
      var annotations = cursor.segment.annotations;        
      
      for (var a in annotations) {
        var annotation = annotations[a];
        
        // use the Rehearsal Mark by perference, otherwise the double bar line... 
        if (annotation.name == "RehearsalMark") 
        {
          rehearsalMarks.push({text: annotation.text, value: cursor.tick });
        }
      }

      cursor.next();
    }
    
    // second pass to add in the measure numbers after the double bar line, IF they aren't already included.   
    var measure = curScore.firstMeasure;
    var measureNumber = 1;
    
    while (measure)
    {
      var segment = measure.lastSegment;
      var barLine = segment.elementAt(0);   // element in Track 0 -- but its if its a double bar line, it'll across all tracks

      if ((barLine.type != Element.BAR_LINE) || (barLine.barlineType != 2)) {
        measure = measure.nextMeasure;
        measureNumber++;
        continue;
      }
      
      // found a double bar line, so get the tick of the start of the NEXT bar... 
      measure = measure.nextMeasure;
      measureNumber++;

      segment = measure.firstSegment;
      while (segment.segmentType != Segment.ChordRest) {
        segment = segment.nextInMeasure;
      }
      
      if (segment == null) continue;
      
      // only add it to the list if there isn't already a rehearsal mark there.. 
      var alreadyExists = false;
      for (var rh in rehearsalMarks)
      {
        if (rehearsalMarks[rh].value ==  segment.tick)
        {
          alreadyExists = true;
          break;
        }
      }
      
      if (!alreadyExists) {
        rehearsalMarks.push({text: "Measure " + measureNumber, value: segment.tick });
      }
      
    }
  
    // reorder the array by the values, so they appear in order with rehearsal marks
    rehearsalMarks.sort((a, b) => a.value - b.value);

    // reset the combobox to the new array
    rehearsalMarksCombo.model = rehearsalMarks;
    rehearsalMarksCombo.currentIndex = 0;
  }

//=============================================================================

  function nextPlayableSegment(segment)
  {
    var result = segment;
    while (result.segmentType != Segment.ChordRest) {
      result = result.next;
    }
    
    return result;
  }

//=============================================================================

  function playWithLeadIn()
  {
    var cursor = curScore.newCursor();
    cursor.inputStateMode = Cursor.INPUT_STATE_SYNC_WITH_SCORE;

    var measure = cursor.measure;

    if (leadInCombo.currentIndex > 0)
    {
      
      for (var back = 0 ; back < leadInCombo.currentIndex; back++) {
        if (measure.prevMeasure == null) break;    // so we don't go before the first measure
        measure = measure.prevMeasure;
      }
    }
      
    // scroll to the first selectable note
    var segment = nextPlayableSegment(measure.firstSegment);
    
    curScore.startCmd();
      cursor.rewindToTick(segment.tick);
      for (var i = 0; i < curScore.ntracks; i++)
      {
        if (curScore.selection.select(cursor.segment.elementAt(i))) break;
      }
    curScore.endCmd();
    
    cmd("play");
  }
  
//=============================================================================

  function play()
  {
    if (currentPositionButton.checked)
    {
      playFromCursor();
      return;
    }
    
    if (previousPositionButton.checked)
    {
      playFromPreviousPosition();
      return;
    }
    
    if (rehearsalMarkButton.checked)
    {
      playFromRehearsalMark();
      return;
    }
  }

//=============================================================================
  
  function playFromStart()
  {
    curScore.startCmd();
      var cursor = curScore.newCursor();
      cursor.rewindToTick(curScore.firstSegment.tick);
    curScore.endCmd();
    
    playWithLeadIn()
  }
  
//=============================================================================
  
  function playFromCursor()
  {
    lastCursorPosition.isRange     = curScore.selection.isRange;
    lastCursorPosition.element     = curScore.selection.elements[0];
    lastCursorPosition.startTick   = lastCursorPosition.isRange ? curScore.selection.startSegment.tick : 0;
    lastCursorPosition.endTick     = lastCursorPosition.isRange ? curScore.selection.endSegment.tick : 0;
    lastCursorPosition.startStaff  = curScore.selection.startStaff;
    lastCursorPosition.endStaff    = curScore.selection.endStaff;
    
    playWithLeadIn()
  }

//=============================================================================

  function playFromPreviousPosition()
  {
    curScore.startCmd();
      if (lastCursorPosition.isRange) 
      {
        // a range was previously selected, so restore that selected range
        curScore.selection.selectRange(lastCursorPosition.startTick, lastCursorPosition.endTick, lastCursorPosition.startStaff, lastCursorPosition.endStaff); 
      }
      else 
      {
        // not a previous range, so just the first element will do
        curScore.selection.select(lastCursorPosition.element);
      }
    curScore.endCmd();
    
    playWithLeadIn()
  }

//=============================================================================

  function playFromRehearsalMark()
  {
    var selectedMark = rehearsalMarks[rehearsalMarksCombo.currentIndex];
    
    // select the first element at that tick
    var cursor = curScore.newCursor();
    
    curScore.startCmd();
      cursor.rewindToTick(selectedMark.value);
      
      for (var i = 0; i < curScore.ntracks; i++)
      {
        if (curScore.selection.select(cursor.segment.elementAt(i))) break;
      }
    curScore.endCmd();
    
    playWithLeadIn()
  }

//=============================================================================

  onRun: 
  {
    if ((mscoreMajorVersion <= 3) || ((mscoreMajorVersion == 4 && mscoreMinorVersion < 4 ))) 
    {
      showMessage("Play From is for MuseScore 4.4 or later");
      (typeof(quit) === 'undefined' ? Qt.quit : quit)()
      return;
    }
  
    findRehearsalMarks();
  }
      
}