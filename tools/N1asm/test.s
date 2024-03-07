                CPU     N1
                SETDP   $FF00

UIMM_MAX        EQU      31
SIMM_MIN        EQU     -16
OIMM_ZERO       EQU       0

                ORG     $0000, $8000

                !                                               ;; 02FF
                !       STORE_ADDR                              ;; 02FF
                *                                               ;; 0E00
                *       UIMM_MAX                                ;; 0E00
                +                                               ;; 0C00
                +       UIMM_MAX                                ;; 0C00
                +!                                              ;; 0403 03FF 0C00 0755 02FF
                -                                               ;; 0C40
                -       UIMM_MAX                                ;; 0C40
                0<                                              ;; 0DF0
                0<>                                             ;; 0D70
                0>                                              ;; 0DB0
                0=                                              ;; 0D30
                1+                                              ;; 0C01
                1-                                              ;; 0C0F
                2!                                              ;; 0750 0460 02FF 0C01 02FF
                2*                                              ;; 0F41
                2/                                              ;; 0f01
                2@                                              ;; 0750 0C01 03FF 0418 03FF
                2DROP                                           ;; 06A8 06A8
                2DUP                                            ;; 0758 0758
                2OVER                                           ;; 0750 0460 0758 0460
                2>R                                             ;; 06AB 06AB
                2R>                                             ;; 0755 0755
                2R@                                             ;; 0755 0757
                2ROT                                            ;; 06AB 0580 06AB 0598 0755 0598 0755 0598 0460
                2SWAP                                           ;; 0460 0598 0460
                ;                                               ;; 8400
                <                                               ;; 0DA0
                <        OIMM_ZERO                              ;; 0DA0
                <>                                              ;; 0D40
                <>       UIMM_MAX                               ;; 0D40
                <>       OIMM_ZERO                              ;; 0D40
                =                                               ;; 0D00
                =        UIMM_MAX                               ;; 0D00
                =        OIMM_ZERO                              ;; 0D00
                >                                               ;; 0DE0
                >        OIMM_ZERO                              ;; 0DE0
                >R                                              ;; 06AB
                ?DUP                                            ;; 0750 0D30 2001 06A8
                ?DUP                                            ;; 0750 0D30 2001 06A8
                @                                               ;; 03FF
                @         FETCH_ADDR                            ;; 03FF
                ABS                                             ;; 0C30
                AND                                             ;; 0E80
                AND       UIMM_MAX                              ;; 0E80
                BL                                              ;; 1020
                BRANCH    BRANCH_ADDR                           ;; 4000
BRANCH_ADDR     CALL                                            ;; 7FFF
                CALL      CALL_ADDR                             ;; 7FFF
CALL_ADDR       CELL+                                           ;; 0C01
                CLRPS                                           ;; 1000 0000
                CLRRS                                           ;; 1000 0001
                DEPTH                                           ;; 0100
                DROP                                            ;; 06A8
                DUP                                             ;; 0750
                EKEY                                            ;; 0107
                EKEY?                                           ;; 0104
                EMIT                                            ;; 0005
                EMIT?                                           ;; 0105
                EXECUTE                                         ;; 7FFF
                FALSE                                           ;; 1000
                I                                               ;; 0754
                IDIS                                            ;; 1000 0003
                IEN                                             ;; 1FFF 0003
                IEN?                                            ;; 0103
                INVERT                                          ;; 0EBF
                J                                               ;; 0755 0407
                JUMP                                            ;; FFFF
                JUMP      JUMP_ADDR                             ;; FFFF
JUMP_ADDR       LITERAL   1234                                  ;; 1000
                LSHIFT                                          ;; 0F20
                LSHIFT    UIMM_MAX                              ;; 0F20
                M*                                              ;; 0A40
                M*        SIMM_MIN                              ;; 0A40
                M+                                              ;; 0800
                M+        UIMM_MAX                              ;; 0800
                MAX                                             ;; OCA0
                MAX       OIMM_ZERO                             ;; 0CA0
                MIN                                             ;; 0CE0
                MIN       OIMM_ZERO                             ;; 0CE0
                NEGATE                                          ;; 0C70
                NIP                                             ;; 06A0
                OR                                              ;; 0EC0
                OR        UIMM_MAX                              ;; 0EC0
                OVER                                            ;; 0758
                PEEK                                            ;; 0106
                R>                                              ;; 0755
                R@                                              ;; 0754
                RDEPTH                                          ;; 0101
                RSHIFT                                          ;; 0F00
                RSHIFT    UIMM_MAX                              ;; 0F00
                ROT                                             ;; 0460 0418
                ROTX                                            ;; 041C
                STACK  ->PS3->PS2->PS1->PS0->RS0->              ;; 0400
                S>D                                             ;; 0A41
                SWAP                                            ;; 0418
                SWAP-                                           ;; 0418
                SWAP-      OIMM_ZERO                            ;; 0418
                TRUE                                            ;; 1FFF
                TUCK                                            ;; 0750 0460
                TUCKX                                           ;; 07C0
                U<                                              ;; 0DC0
                U<        UIMM_MAX                              ;; 0DC0
                U>                                              ;; 0D80
                U>        UIMM_MAX                              ;; 0D80
                UM*                                             ;; 0A00
                UM*       UIMM_MAX                              ;; 0A00
                XOR                                             ;; 0EA0
                XOR       UIMM_MAX                              ;; 0EA0

                ORG     $1000, $9000

                !                                       ;       ;; 02FF
                !       STORE_ADDR                      ;       ;; 02FF
                *                                       ;       ;; 0E00
                *       UIMM_MAX                        ;       ;; 0E00
                +                                       ;       ;; 0C00
                +       UIMM_MAX                        ;       ;; 0C00
                +!                                      ;       ;; 0403 03FF 0C00 0755 02FF
                -                                       ;       ;; 0C40
                -       UIMM_MAX                        ;       ;; 0C40
                0<                                      ;       ;; 0DF0
                0<>                                     ;       ;; 0D70
                0>                                      ;       ;; 0DB0
                0=                                      ;       ;; 0D30
                1+                                      ;       ;; 0C01
                1-                                      ;       ;; 0C0F
                2!                                      ;       ;; 0750 0460 02FF 0C01 02FF
                2*                                      ;       ;; 0F41
                2/                                      ;       ;; 0f01
                2@                                      ;       ;; 0750 0C01 03FF 0418 03FF
                2DROP                                   ;       ;; 06A8 06A8
                2DUP                                    ;       ;; 0758 0758
                2OVER                                   ;       ;; 0750 0460 0758 0460
                2>R                                     ;       ;; 06AB 06AB
                2R>                                     ;       ;; 0755 0755
                2R@                                     ;       ;; 0755 0757
                2ROT                                    ;       ;; 06AB 0580 06AB 0598 0755 0598 0755 0598 0460
                2SWAP                                   ;       ;; 0460 0598 0460
                ;                                       ;       ;; 8400
                <                                       ;       ;; 0DA0
                <        OIMM_ZERO                      ;       ;; 0DA0
                <>                                      ;       ;; 0D40
                <>       UIMM_MAX                       ;       ;; 0D40
                <>       OIMM_ZERO                      ;       ;; 0D40
                =                                       ;       ;; 0D00
                =        UIMM_MAX                       ;       ;; 0D00
                =        OIMM_ZERO                      ;       ;; 0D00
                >                                       ;       ;; 0DE0
                >        OIMM_ZERO                      ;       ;; 0DE0
                >R                                      ;       ;; 06AB
                ?DUP                                    ;       ;; 0750 0D30 2001 06A8
                ?DUP                                    ;       ;; 0750 0D30 2001 06A8
                @                                       ;       ;; 03FF
                @         FETCH_ADDR                    ;       ;; 03FF
                ABS                                     ;       ;; 0C30
                AND                                     ;       ;; 0E80
                AND       UIMM_MAX                      ;       ;; 0E80
                BL                                      ;       ;; 1020
                BRANCH    BRANCH_ADDR_SEM               ;       ;; 4000
BRANCH_ADDR_SEM CALL                                    ;       ;; 7FFF
                CALL      CALL_ADDR_SEM                 ;       ;; 7FFF
CALL_ADDR_SEM   CELL+                                   ;       ;; 0C01
                CLRPS                                   ;       ;; 1000 0000
                CLRRS                                   ;       ;; 1000 0001
                DEPTH                                   ;       ;; 0100
                DROP                                    ;       ;; 06A8
                DUP                                     ;       ;; 0750
                EKEY                                    ;       ;; 0107
                EKEY?                                   ;       ;; 0104
                EMIT                                    ;       ;; 0005
                EMIT?                                   ;       ;; 0105
                EXECUTE                                 ;       ;; 7FFF
                FALSE                                   ;       ;; 1000
                I                                       ;       ;; 0754
                IDIS                                    ;       ;; 1000 0003
                IEN                                     ;       ;; 1FFF 0003
                IEN?                                    ;       ;; 0103
                INVERT                                  ;       ;; 0EBF
                J                                       ;       ;; 0755 0407
                JUMP                                    ;       ;; FFFF
                JUMP      JUMP_ADDR_SEM                 ;       ;; FFFF
JUMP_ADDR_SEM   LITERAL   1234                          ;       ;; 1000
                LSHIFT                                  ;       ;; 0F20
                LSHIFT    UIMM_MAX                      ;       ;; 0F20
                M*                                      ;       ;; 0A40
                M*        SIMM_MIN                      ;       ;; 0A40
                M+                                      ;       ;; 0800
                M+        UIMM_MAX                      ;       ;; 0800
                MAX                                     ;       ;; OCA0
                MAX       OIMM_ZERO                     ;       ;; 0CA0
                MIN                                     ;       ;; 0CE0
                MIN       OIMM_ZERO                     ;       ;; 0CE0
                NEGATE                                  ;       ;; 0C70
                NIP                                     ;       ;; 06A0
                OR                                      ;       ;; 0EC0
                OR        UIMM_MAX                      ;       ;; 0EC0
                OVER                                    ;       ;; 0758
                PEEK                                    ;       ;; 0106
                R>                                      ;       ;; 0755
                R@                                      ;       ;; 0754
                RDEPTH                                  ;       ;; 0101
                RSHIFT                                  ;       ;; 0F00
                RSHIFT    UIMM_MAX                      ;       ;; 0F00
                ROT                                     ;       ;; 0460 0418
                ROTX                                    ;       ;; 041C
                STACK  ->PS3->PS2->PS1->PS0->RS0->      ;       ;; 0400
                S>D                                     ;       ;; 0A41
                SWAP                                    ;       ;; 0418
                SWAP-                                   ;       ;; 0418
                SWAP-      OIMM_ZERO                    ;       ;; 0418
                TRUE                                    ;       ;; 1FFF
                TUCK                                    ;       ;; 0750 0460
                TUCKX                                   ;       ;; 07C0
                U<                                      ;       ;; 0DC0
                U<        UIMM_MAX                      ;       ;; 0DC0
                U>                                      ;       ;; 0D80
                U>        UIMM_MAX                      ;       ;; 0D80
                UM*                                     ;       ;; 0A00
                UM*       UIMM_MAX                      ;       ;; 0A00
                XOR                                     ;       ;; 0EA0
                XOR       UIMM_MAX                      ;       ;; 0EA0

                ORG     $2000, $A000

                DW      BRANCH_ADDR
                DW      CALL_ADDR
                DW      JUMP_ADDR

                FCC     "ABCDEF"
                FCS     "ABCDEF"
                FCZ     "ABCDEF"
                FCC     "ABCDEFG"
                FCS     "ABCDEFG"
                FCZ     "ABCDEFG"

FLET32_START    FILL    $ABCD, 8
FLET32_END      EQU     *-1

                FLET32  FLET32_START, FLET32_END

                LOC
LABEL`          DW      0
                LOC
LABEL`          DW      0
                LOC
LABEL`          DW      0
                LOC
LABEL`          DW      0
                DW      LABEL0001 LABEL0002 LABEL0003 LABEL0004

                ALIGN   $0F
                DW      0
                ALIGN   $0F, $1234

                UNALIGN $0F
                DW      0
                UNALIGN $0F, $1234
                DW      0

#MACRO          :       2
HEADER_START    DW      ((§2&$FF)<<8)|(CODE_START-*)
NAME            FCS     §1
CODE_START      EQU     *
#EMAC

                ORG     $8000, $F000
                :       "XOR", $00
                XOR     ;

                :       "2ROT", $00
                2ROT    ;

                :       "LSHIFT", $00
                LSHIFT  ;

                ORG     $FFF0, $4FF0
FETCH_ADDR      RMW     4
STORE_ADDR      RMW     4
