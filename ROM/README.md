# ROM
 バッテリーバックアップRAMボードMZ-1R12のようなものを64KB対応するための9Z-502M-1.0Cに対する差分など
 パッチ当ては
 https://github.com/ecodacs-ecd102/MZ1200-700/tree/main/tools
 のbpatch.plなどで。

## 9Z-502M-1.0C+patch-1R12-64K.bdiff
 1Z-1R12モドキ(64KB)に対応させるためのパッチ

## 9Z-502M+EC_EQ.bdiff
 9Z-102MにECコマンド(SRAM クリア)、EQコマンド(QDからSRAMへ書き込み)の追加を行うパッチ

## EQ_CMD.ASM
 EC,EQコマンド差分のソース z80asm 用
