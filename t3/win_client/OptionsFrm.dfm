object OptionsForm: TOptionsForm
  Left = 660
  Top = 241
  BorderIcons = []
  BorderStyle = bsSingle
  Caption = 'General Options'
  ClientHeight = 326
  ClientWidth = 442
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
    FF00000000000000000000FFFF7007FFFF0FFFFFFFF77FFFFFFFF0FFFF7007FF
    FF0FFFFFFFFFFFFFFFFFF0FFFF7007FFFF0FFFFFFFFFFFFFFFFFF0FFFF7007FF
    FF0FFFFFFFFFFFFFFFFFF0FFFF7007FFFF0FFFFFFFFFFFFFFFFFF0FFFF7007FF
    FF0FFFFFFFFFFFFFFFFFF0FFFF7007FFFF0FFFFFFFFFFFFFFFFFF0FFFF7007FF
    FF0FFFFFFFFFFFFFFFFFF0FFFF7007FFF707FFFFFFFFFFFFFFFF707FFF7007FF
    F707FFFFFFF00FFFFFFF707FFF7007FFFF0FFFFFFFF00FFFFFFFF0FFFF7007FF
    FF0FFFFFFFF00FFFFFFFF0FFFF7007FFFF0FFFFFFFF00FFFFFFFF0FFFF7007FF
    FF0FFFFFFFF00FFFFFFFF0FFFF7007FFFF0FFFFFFFF00FFFFFFFF0FFFF7007FF
    FF0FFFFFFFF00FFFFFFFF0FFFF7007FFFF0FFFFFFFF00FFFFFFFF0FFFF7007FF
    FF0FFFFFFFF00FFFFFFFF0FFFF7007FFFF00000000000000000000FFFF7007FF
    FFFFFFFFFFF00FFFFFFFFFFFFF7007FFFFFFFFFFFFFFFFFFFFFFFFFFFF7007FF
    FFFFFFFFFFFFFFFFFFFFFFFFFF7007FFFFFFFFFFFFFFFFFFFFFFFFFFFF700777
    7777777777777777777777777770000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000000000000}
  OldCreateOrder = False
  Position = poScreenCenter
  Scaled = False
  OnClose = FormClose
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object TabOptions: TPageControl
    Left = 0
    Top = 29
    Width = 442
    Height = 297
    ActivePage = TalkerOptions
    Align = alClient
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    HotTrack = True
    ParentFont = False
    TabOrder = 0
    object TalkerOptions: TTabSheet
      Caption = ' &Talker '
      object Label1: TLabel
        Left = 18
        Top = 8
        Width = 56
        Height = 14
        Caption = 'User Name:'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label2: TLabel
        Left = 226
        Top = 56
        Width = 104
        Height = 14
        Caption = 'Contact Server Every'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label3: TLabel
        Left = 277
        Top = 77
        Width = 43
        Height = 14
        Alignment = taRightJustify
        Caption = 'Seconds'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label4: TLabel
        Left = 18
        Top = 56
        Width = 59
        Height = 14
        Caption = 'Server URL:'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label5: TLabel
        Left = 18
        Top = 152
        Width = 131
        Height = 14
        Caption = 'Message Divider in History:'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label6: TLabel
        Left = 226
        Top = 152
        Width = 114
        Height = 14
        Caption = 'Message Window Font:'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object SetMessageFont: TSpeedButton
        Left = 370
        Top = 169
        Width = 20
        Height = 20
        Hint = 'Select Message Font'
        Caption = 'F'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -12
        Font.Name = 'Arial'
        Font.Style = [fsBold, fsItalic]
        ParentFont = False
        ParentShowHint = False
        ShowHint = True
        OnClick = SetMessageFontClick
      end
      object Label7: TLabel
        Left = 226
        Top = 8
        Width = 60
        Height = 14
        Caption = 'User Status:'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label9: TLabel
        Left = 18
        Top = 104
        Width = 112
        Height = 14
        Caption = 'Got-a-Message Sound:'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label10: TLabel
        Left = 226
        Top = 104
        Width = 85
        Height = 14
        Caption = 'Play Sound Every'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object Label11: TLabel
        Left = 277
        Top = 125
        Width = 43
        Height = 14
        Alignment = taRightJustify
        Caption = 'Seconds'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
      end
      object UserName: TEdit
        Left = 16
        Top = 24
        Width = 185
        Height = 22
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        Text = 'UserName'
      end
      object RefreshFrequency: TEdit
        Left = 224
        Top = 72
        Width = 33
        Height = 23
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        Text = '30'
      end
      object RefreshFrequencyChange: TUpDown
        Left = 257
        Top = 72
        Width = 15
        Height = 23
        Associate = RefreshFrequency
        Min = 1
        Max = 180
        Position = 30
        TabOrder = 6
        Wrap = True
      end
      object CloseOnSend: TCheckBox
        Left = 16
        Top = 208
        Width = 193
        Height = 25
        Caption = 'Close Message window on Send'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 5
      end
      object ServerURL: TEdit
        Left = 16
        Top = 72
        Width = 185
        Height = 22
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        Text = 'ServerURL'
      end
      object HistoryDivider: TEdit
        Left = 16
        Top = 168
        Width = 185
        Height = 22
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 3
        Text = '--------------------'
      end
      object MessageFont: TEdit
        Left = 224
        Top = 168
        Width = 145
        Height = 22
        AutoSize = False
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        TabOrder = 4
        Text = 'Arial'
      end
      object TestMode: TCheckBox
        Left = 346
        Top = 73
        Width = 73
        Height = 25
        Caption = 'Test Mode'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 7
      end
      object UserStatus: TEdit
        Left = 224
        Top = 24
        Width = 193
        Height = 22
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 8
        Text = 'UserStatus'
      end
      object SelectMode: TCheckBox
        Left = 16
        Top = 232
        Width = 377
        Height = 17
        Caption = 
          'Use CTRL and SHIFT keys to select multiple users on Message wind' +
          'ow'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 9
      end
      object ReplaySound: TEdit
        Left = 224
        Top = 120
        Width = 33
        Height = 23
        Hint = 'Set to 0 to play only once'
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        Text = '180'
      end
      object ReplaySoundChange: TUpDown
        Left = 257
        Top = 120
        Width = 16
        Height = 23
        Hint = 'Set to 0 to play only once'
        Associate = ReplaySound
        Min = 0
        Max = 1800
        ParentShowHint = False
        Position = 180
        ShowHint = True
        TabOrder = 11
        Thousands = False
        Wrap = True
      end
      object SoundOff: TCheckBox
        Left = 346
        Top = 118
        Width = 73
        Height = 25
        Caption = 'No Sound'
        Font.Charset = ANSI_CHARSET
        Font.Color = clNavy
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ParentFont = False
        TabOrder = 12
        OnClick = SoundOffClick
      end
      object MessageSound: TComboBox
        Left = 16
        Top = 120
        Width = 153
        Height = 22
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Arial'
        Font.Style = []
        ItemHeight = 14
        ParentFont = False
        TabOrder = 13
      end
    end
    object TimerOptions: TTabSheet
      Caption = ' &Timer '
      ImageIndex = 1
      TabVisible = False
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 442
    Height = 29
    Align = alTop
    TabOrder = 1
    object Label8: TLabel
      Left = 8
      Top = 6
      Width = 158
      Height = 14
      Caption = 'Development Release version 13'
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
    end
    object Save: TBitBtn
      Left = 380
      Top = 2
      Width = 25
      Height = 25
      Hint = 'OK'
      Anchors = [akTop, akRight]
      ModalResult = 1
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      Glyph.Data = {
        66010000424D6601000000000000760000002800000014000000140000000100
        040000000000F000000000000000000000001000000010000000000000000000
        8000008000000080800080000000800080008080000080808000C0C0C0000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00FFFFFFFFFFFF
        FFFFFFFF0000FFFFFFFFFFFFFFFFFFFF0000FFFFFF47FFFFFFFFFFFF0000FFFF
        F4477FFFFFFFFFFF0000FFFFF4447FFFFFFFFFFF0000FFFF444447FFFFFFFFFF
        0000FFFF444447FFFFFFFFFF0000FFF44474447FFFFFFFFF0000FF4447F7447F
        FFFFFFFF0000F44447FF4447FFFFFFFF0000FF447FFFF4477FFFFFFF0000FFFF
        FFFFFF447FFFFFFF0000FFFFFFFFFFF447FFFFFF0000FFFFFFFFFFFF447FFFFF
        0000FFFFFFFFFFFFF447FFFF0000FFFFFFFFFFFFFF447FFF0000FFFFFFFFFFFF
        FFF447FF0000FFFFFFFFFFFFFFFF44FF0000FFFFFFFFFFFFFFFFFFFF0000FFFF
        FFFFFFFFFFFFFFFF0000}
    end
    object Cancel: TBitBtn
      Left = 408
      Top = 2
      Width = 25
      Height = 25
      Hint = 'Cancel'
      Anchors = [akTop, akRight]
      ModalResult = 2
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      Glyph.Data = {
        66010000424D6601000000000000760000002800000014000000140000000100
        040000000000F000000000000000000000001000000010000000000000000000
        8000008000000080800080000000800080008080000080808000C0C0C0000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00FFFFFFFFFFFF
        FFFFFFFF0000FFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF0000FFFF
        17FFFFFFFFFFFFFF0000FFF9917FFFFFF917FFFF0000FF999917FFFF99997FFF
        0000FFFF99917FF99917FFFF0000FFFFFF99179997FFFFFF0000FFFFFFF99199
        7FFFFFFF0000FFFFFFFF9991FFFFFFFF0000FFFFFFF999917FFFFFFF0000FFFF
        FF99919917FFFFFF0000FFFFF9991F999177FFFF0000FFFF99917FF999117FFF
        0000FFFF9997FFFF99991FFF0000FFFFF917FFFFF991FFFF0000FFFFFFFFFFFF
        FFFFFFFF0000FFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF0000FFFF
        FFFFFFFFFFFFFFFF0000}
    end
  end
  object FontDialog1: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    MinFontSize = 0
    MaxFontSize = 0
    Left = 316
    Top = 249
  end
end
