object MessageActionForm: TMessageActionForm
  Left = 617
  Top = 453
  Width = 435
  Height = 293
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSizeToolWin
  Caption = 'Message'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
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
  Position = poScreenCenter
  Scaled = False
  OnClose = FormClose
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Panel2: TPanel
    Left = 0
    Top = 30
    Width = 108
    Height = 239
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object ClearMessage: TButton
      Left = 0
      Top = 186
      Width = 105
      Height = 25
      Anchors = [akLeft, akBottom]
      Caption = '&Clear Message'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 2
      OnClick = ClearMessageClick
    end
    object CloseForm: TButton
      Left = 0
      Top = 210
      Width = 105
      Height = 25
      Anchors = [akLeft, akBottom]
      Caption = 'C&lose'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = CloseFormClick
    end
    object GetMessg: TButton
      Left = 0
      Top = 0
      Width = 105
      Height = 25
      Caption = 'Read &Next'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      OnClick = GetMessgClick
    end
    object UserList: TListBox
      Left = 0
      Top = 103
      Width = 105
      Height = 84
      Anchors = [akLeft, akTop, akBottom]
      Color = 13682888
      ExtendedSelect = False
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ItemHeight = 14
      MultiSelect = True
      ParentFont = False
      ParentShowHint = False
      ShowHint = False
      TabOrder = 3
      OnClick = UserListClick
    end
    object All: TButton
      Left = 0
      Top = 88
      Width = 52
      Height = 17
      Caption = '&All'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      TabOrder = 5
      OnClick = AllClick
    end
    object None: TButton
      Left = 52
      Top = 88
      Width = 53
      Height = 17
      Caption = '&None'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      TabOrder = 6
      OnClick = AllClick
    end
    object SendMessg: TBitBtn
      Left = 0
      Top = 24
      Width = 53
      Height = 36
      Caption = '&Send'
      Font.Charset = ANSI_CHARSET
      Font.Color = clPurple
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 8
      OnClick = SendMessgClick
    end
    object ReplyMessg: TBitBtn
      Left = 52
      Top = 24
      Width = 53
      Height = 36
      Caption = '&Reply'
      Enabled = False
      Font.Charset = ANSI_CHARSET
      Font.Color = clPurple
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 7
      OnClick = ReplyMessgClick
    end
    object BroadcastMessg: TButton
      Left = 0
      Top = 59
      Width = 105
      Height = 25
      Caption = '&Broadcast'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 4
      OnClick = BroadcastMessgClick
    end
  end
  object Panel1: TPanel
    Left = 108
    Top = 30
    Width = 319
    Height = 239
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object TheMessage: TMemo
      Left = 0
      Top = 0
      Width = 319
      Height = 239
      Align = alClient
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssVertical
      TabOrder = 0
      WantTabs = True
      OnChange = TheMessageChange
      OnKeyDown = TheMessageKeyDown
      OnKeyUp = TheMessageKeyUp
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 0
    Width = 427
    Height = 30
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 2
    object Label1: TLabel
      Left = 62
      Top = 7
      Width = 44
      Height = 15
      Caption = 'Subject:'
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -12
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
    end
    object ReplyLED: TLabel
      Left = 40
      Top = 4
      Width = 14
      Height = 22
      Caption = '®'
      Font.Charset = ANSI_CHARSET
      Font.Color = clRed
      Font.Height = -19
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
      Visible = False
    end
    object Label2: TLabel
      Left = 201
      Top = 7
      Width = 20
      Height = 15
      Caption = 'Kw:'
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -12
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
    end
    object ShowHistory: TSpeedButton
      Left = 4
      Top = 2
      Width = 26
      Height = 25
      Hint = 'History On/Off'
      AllowAllUp = True
      GroupIndex = 1
      Flat = True
      Glyph.Data = {
        96030000424D9603000000000000760000002800000050000000140000000100
        0400000000002003000000000000000000001000000010000000000000000000
        8000008000000080800080000000800080008080000080808000C0C0C0000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888887777788888777778888877777
        8888877777888887777788888777778888877777888887777788885555578888
        5555578888999997888899999788885555578888555557888899999788889999
        9788888555788888855578888889997888888999788888855578888885557888
        8889997888888999788888855578888885557888888999788888899978888885
        5578888885557888888999788888899978888885557888888555788888899978
        8888899978888885557888888555788888899978888889997888888555777777
        7555788888899977777779997888888555777777755578888889997777777999
        7888888555555555555578888889999999999999788888855555555555557888
        8889999999999999788888855555555555557888888999999999999978888885
        5555555555557888888999999999999978888885555555555555788888899999
        9999999978888885555555555555788888899999999999997888888555788888
        8555788888899978888889997888888555788888855578888889997888888999
        7888888555788888855578888889997888888999788888855578888885557888
        8889997888888999788888855578888885557888888999788888899978888885
        5578888885557888888999788888899978888885557788888555778888899977
        8888899977888885557788888555778888899977888889997788885555588888
        5555588888999998888899999888885555588888555558888899999888889999
        9888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888888888}
      NumGlyphs = 4
      ParentShowHint = False
      ShowHint = True
      OnClick = ShowHistoryClick
    end
    object HistButton: TButton
      Left = 152
      Top = 8
      Width = 17
      Height = 12
      Caption = '&H'
      TabOrder = 5
      OnClick = HistButtonClick
    end
    object Topic: TEdit
      Left = 109
      Top = 4
      Width = 318
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      Color = clBtnFace
      Ctl3D = True
      ParentCtl3D = False
      TabOrder = 0
    end
    object FilterSubject: TEdit
      Left = 109
      Top = 4
      Width = 81
      Height = 21
      Color = 13682888
      TabOrder = 1
      Visible = False
    end
    object FilterKw: TEdit
      Left = 224
      Top = 4
      Width = 81
      Height = 21
      Color = 13682888
      TabOrder = 2
      Visible = False
    end
    object FilterThread: TCheckBox
      Left = 328
      Top = 6
      Width = 65
      Height = 17
      Caption = 'Thread'
      Color = clBtnFace
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -12
      Font.Name = 'Arial'
      Font.Style = []
      ParentColor = False
      ParentFont = False
      TabOrder = 3
      Visible = False
    end
    object ApplyFilter: TButton
      Left = 382
      Top = 4
      Width = 41
      Height = 21
      Hint = 'Apply Filters'
      Anchors = [akTop, akRight]
      Caption = 'A&pply'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 4
      Visible = False
      OnClick = ApplyFilterClick
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
    Left = 136
    Top = 216
  end
  object MessageCheck: TTimer
    OnTimer = MessageCheckTimer
    Left = 172
    Top = 216
  end
end
