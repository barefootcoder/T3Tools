object NewTimer: TNewTimer
  Left = 226
  Top = 404
  HorzScrollBar.Visible = False
  VertScrollBar.Visible = False
  BorderIcons = []
  BorderStyle = bsSingle
  Caption = 'New Timer'
  ClientHeight = 310
  ClientWidth = 260
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
  KeyPreview = True
  OldCreateOrder = False
  Position = poDefault
  Scaled = False
  OnClose = FormClose
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 24
    Width = 72
    Height = 15
    Caption = 'Timer &Name:'
    FocusControl = TimerName
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Label2: TLabel
    Left = 8
    Top = 232
    Width = 66
    Height = 15
    Caption = '&Description:'
    FocusControl = TimerNotes
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Label3: TLabel
    Left = 8
    Top = 188
    Width = 29
    Height = 15
    Caption = '&Date:'
    FocusControl = TimerDate
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Label4: TLabel
    Left = 144
    Top = 188
    Width = 37
    Height = 15
    Caption = '&Hours:'
    FocusControl = TimerHours
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Label5: TLabel
    Left = 8
    Top = 144
    Width = 41
    Height = 15
    Caption = 'Pro&ject:'
    FocusControl = TimerProject
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Label6: TLabel
    Left = 144
    Top = 144
    Width = 39
    Height = 15
    Caption = '&Phase:'
    FocusControl = TimerPhase
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Label7: TLabel
    Left = 8
    Top = 68
    Width = 35
    Height = 15
    Caption = '&Client:'
    FocusControl = TimerClient
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
  end
  object Bevel1: TBevel
    Left = 4
    Top = 88
    Width = 253
    Height = 50
    Shape = bsBottomLine
  end
  object TimerNotes: TMemo
    Left = 8
    Top = 248
    Width = 243
    Height = 53
    Anchors = [akLeft, akTop, akRight]
    Color = clBtnFace
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 6
  end
  object TimerName: TEdit
    Left = 8
    Top = 40
    Width = 243
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    Font.Charset = ANSI_CHARSET
    Font.Color = clBlack
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
    OnKeyPress = TimerNameKeyPress
  end
  object TimerDate: TEdit
    Left = 8
    Top = 204
    Width = 121
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 4
  end
  object TimerHours: TEdit
    Left = 144
    Top = 204
    Width = 105
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 5
  end
  object TimerProject: TComboBox
    Left = 8
    Top = 160
    Width = 121
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ItemHeight = 15
    ParentFont = False
    TabOrder = 2
  end
  object TimerPhase: TComboBox
    Left = 144
    Top = 160
    Width = 105
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ItemHeight = 15
    ParentFont = False
    TabOrder = 3
  end
  object TimerClient: TComboBox
    Left = 8
    Top = 84
    Width = 241
    Height = 23
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ItemHeight = 15
    ParentFont = False
    TabOrder = 1
  end
  object Save: TBitBtn
    Left = 196
    Top = 6
    Width = 25
    Height = 25
    Hint = 'OK'
    ModalResult = 1
    ParentShowHint = False
    ShowHint = True
    TabOrder = 7
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
    Left = 224
    Top = 6
    Width = 25
    Height = 25
    Hint = 'Cancel'
    ModalResult = 2
    ParentShowHint = False
    ShowHint = True
    TabOrder = 8
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
  object chkHalfTime: TCheckBox
    Left = 8
    Top = 112
    Width = 237
    Height = 17
    Caption = '&Half Time'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 9
  end
end
