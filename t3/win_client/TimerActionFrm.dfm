object TimerActionForm: TTimerActionForm
  Left = 270
  Top = 538
  BorderIcons = [biSystemMenu]
  BorderStyle = bsToolWindow
  Caption = ' '
  ClientHeight = 212
  ClientWidth = 104
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  FormStyle = fsStayOnTop
  Icon.Data = {
    0000010001002020100000000000E80200001600000028000000200000004000
    0000010004000000000080020000000000000000000000000000000000000000
    000000008000008000000080800080000000800080008080000080808000C0C0
    C0000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF000000
    00000000000000000000000000000777777777777777777777777777777007FF
    FFFFFFFFFFFFFFFFFFFFFFFFFF7007FFFFFFFFFFFFFFFFFFFFFFFFFFFF7007FF
    FFFFFFFFFFFFFFFFFFFFFFFFFF7007FFFFFFFFFFFFF77FFFFFFFFFFFFF7007FF
    FF99999999900999999999FFFF7007FFFF99999999977999999999FFFF7007FF
    FF99999999999999999999FFFF7007FFFF99999999999999999999FFFF7007FF
    FF99999999999999999999FFFF7007FFFF99999999999999999999FFFF7007FF
    FF99999999999999999999FFFF7007FFFF99999999999999999999FFFF7007FF
    FF99999999999999999999FFFF7007FFF7079999999999999999707FFF7007FF
    F7079999999009999999707FFF7007FFFF99999999900999999999FFFF7007FF
    FF99999999900999999999FFFF7007FFFF99999999900999999999FFFF7007FF
    FF99999999900999999999FFFF7007FFFF99999999900999999999FFFF7007FF
    FF99999999900999999999FFFF7007FFFF99999999900999999999FFFF7007FF
    FF99999999900999999999FFFF7007FFFF99999999900999999999FFFF7007FF
    FFFFFFFFFFF00FFFFFFFFFFFFF7007FFFFFFFFFFFFFFFFFFFFFFFFFFFF7007FF
    FFFFFFFFFFFFFFFFFFFFFFFFFF7007FFFFFFFFFFFFFFFFFFFFFFFFFFFF700777
    7777777777777777777777777770000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000000000000}
  OldCreateOrder = False
  Scaled = False
  OnClose = FormClose
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object StartTimer: TButton
    Left = 0
    Top = 0
    Width = 105
    Height = 25
    Caption = '&Start'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ModalResult = 1
    ParentFont = False
    TabOrder = 0
    OnClick = StartTimerClick
  end
  object StopTimer: TButton
    Left = 0
    Top = 24
    Width = 105
    Height = 25
    Caption = '&Pause'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ModalResult = 1
    ParentFont = False
    TabOrder = 1
    OnClick = StopTimerClick
  end
  object DoneWithTimer: TButton
    Left = 0
    Top = 48
    Width = 105
    Height = 25
    Caption = '&Done'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ModalResult = 1
    ParentFont = False
    TabOrder = 2
    OnClick = DoneWithTimerClick
  end
  object CancelTimer: TButton
    Left = 0
    Top = 72
    Width = 105
    Height = 25
    Caption = '&Cancel'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ModalResult = 1
    ParentFont = False
    TabOrder = 3
    OnClick = CancelTimerClick
  end
  object Options: TButton
    Left = 0
    Top = 96
    Width = 105
    Height = 25
    Caption = '&Options >>'
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 4
    OnClick = OptionsClick
  end
  object Panel1: TPanel
    Left = 0
    Top = 128
    Width = 104
    Height = 81
    TabOrder = 5
    object Label1: TLabel
      Left = 8
      Top = 8
      Width = 75
      Height = 14
      Caption = 'Bar Max Hours:'
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
    end
    object Label2: TLabel
      Left = 8
      Top = 56
      Width = 111
      Height = 65
      Caption = 
        'Add any other user options here, then apply them in MainForm->se' +
        'tOptions() method'
      Visible = False
      WordWrap = True
    end
    object TimerMaxHours: TEdit
      Left = 40
      Top = 24
      Width = 33
      Height = 21
      TabOrder = 0
      Text = '10'
    end
    object TimerMaxHoursChange: TUpDown
      Left = 73
      Top = 24
      Width = 16
      Height = 21
      Associate = TimerMaxHours
      Min = 0
      Position = 10
      TabOrder = 1
      Wrap = True
    end
  end
end
