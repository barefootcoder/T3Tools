object InTransitForm: TInTransitForm
  Left = 51
  Top = 459
  Width = 600
  Height = 365
  Caption = 'Messages In Transit'
  Color = clBtnFace
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Arial'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PrintScale = poNone
  Scaled = False
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 14
  object Panel1: TPanel
    Left = 0
    Top = 24
    Width = 592
    Height = 317
    Align = alClient
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 425
      Top = 1
      Width = 3
      Height = 315
      Cursor = crHSplit
    end
    object MessageList: TListBox
      Left = 1
      Top = 1
      Width = 424
      Height = 315
      Align = alLeft
      ItemHeight = 14
      TabOrder = 0
      OnClick = MessageListClick
    end
    object DeliveryStatus: TListBox
      Left = 428
      Top = 1
      Width = 163
      Height = 315
      Align = alClient
      ItemHeight = 14
      TabOrder = 1
      OnClick = DeliveryStatusClick
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 0
    Width = 592
    Height = 24
    Align = alTop
    TabOrder = 1
    object Label1: TLabel
      Left = 8
      Top = 7
      Width = 58
      Height = 14
      Caption = 'Messages'
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object Label2: TLabel
      Left = 502
      Top = 7
      Width = 82
      Height = 14
      Alignment = taRightJustify
      Anchors = [akTop, akRight]
      Caption = 'Delivery Status'
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -11
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object Cancel: TBitBtn
      Left = 78
      Top = 5
      Width = 19
      Height = 17
      Hint = 'Remove - Quit Resending Selected Message'
      ModalResult = 2
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = CancelClick
      Glyph.Data = {
        06020000424D0602000000000000760000002800000028000000140000000100
        0400000000009001000000000000000000001000000000000000000000000000
        8000008000000080800080000000800080008080000080808000C0C0C0000000
        FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888881788888888888888
        88888F8888888888888888899178888889178888888778F88888878F88888899
        99178888999978888877778F88887777F8888888999178899917888888887778
        F887778F888888888899179997888888888888778F777F888888888888899199
        78888888888888877877F8888888888888889991888888888888888877788888
        888888888889999178888888888888877778F888888888888899919917888888
        8888887778778F8888888888899918999177888888888777887778FF88888888
        999178899911788888887778F8877788F888888899978888999918888888777F
        888877778888888889178888899188888888878F888887788888888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        8888888888888888888888888888888888888888888888888888888888888888
        88888888888888888888}
      NumGlyphs = 2
    end
  end
  object Refresher: TTimer
    Interval = 5000
    OnTimer = RefresherTimer
    Left = 504
    Top = 73
  end
end
