object InTransitForm: TInTransitForm
  Left = 252
  Top = 302
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
    end
    object DeliveryStatus: TListBox
      Left = 428
      Top = 1
      Width = 163
      Height = 315
      Align = alClient
      ItemHeight = 14
      TabOrder = 1
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
  object Refresher: TTimer
    Interval = 5000
    OnTimer = RefresherTimer
    Left = 504
    Top = 73
  end
end
