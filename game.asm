INCLUDE Irvine32.inc

.data
; Physics Constants
GROUND_Y_POS EQU 29
LANDING_Y_POS EQU 28
JUMP_VELOCITY_INIT SBYTE -4
GRAVITY_ACCEL SBYTE 1
    
; Coin Generation Limits
JUMP_HEIGHT_LIMIT_Y EQU 10
LEFT_LIMIT_X EQU 1
RIGHT_LIMIT_X EQU 70
    
; Mario State
xPos BYTE 1
yPos BYTE LANDING_Y_POS
xOldPos BYTE 1
yOldPos BYTE LANDING_Y_POS
yVelocity SBYTE 0           
on_Ground BYTE 1
    
; Game State Variables
lives BYTE 3
isPaused BYTE 0             
    
; Goomba State Variables
goombaX BYTE 60             
goombaY BYTE LANDING_Y_POS  
goombaActive BYTE 1         
goombaResetTimer BYTE 0

double_jump_allowed BYTE 1  
max_jumps_in_air BYTE 2     
current_jumps_used BYTE 0   

; Coin State Variables
coinX BYTE ?
coinY BYTE ?
coinActive BYTE 0           

; NEW: Startup Screen Art (centered roughly on Y=10)
ArtLine1 BYTE "       /V\          ", 0
ArtLine2 BYTE "      /vvv\         ", 0
ArtLine3 BYTE "     | O O |        ", 0
ArtLine4 BYTE "     |__V__|        ", 0
ArtLine5 BYTE "   / /| | |\ \      ", 0
ArtLine6 BYTE "  | / | | | \ |     ", 0
ArtLine7 BYTE "  \ \|_|_|/ /       ", 0
ArtLine8 BYTE "    /       \       ", 0
ArtLine9 BYTE "  |  SUPER MARIO  | ", 0
ArtLineA BYTE "  |  CS LAB PROJECT |", 0
ArtLineB BYTE "  \ --------------- /", 0
ArtLineC BYTE "    Ready? (3s)     ", 0

ground BYTE " --------------------------------------------------------------------------------------------------------------------------------------------------",0
strScore BYTE "Your score is: ",0
score BYTE 0 ; Score is a single byte, max 255
xCoinPos BYTE ?
yCoinPos BYTE ?
inputChar BYTE ?

strLives BYTE "MARIO LIVES: ",0
GameOverMessage BYTE "GAME OVER. Press X to exit.",0
strPaused BYTE "PAUSED - Press P to continue, Press X to exit.",0 
PAUSE_MSG_LEN EQU ($ - strPaused) 

.code

exitGame:
    exit

; --- STARTUP SCREEN ROUTINE ---
StartupScreen PROC
pushad
    
call Clrscr

mov eax, 000Fh
call SetTextColor

mov dl, 28
mov dh, 10
call Gotoxy
mov edx, OFFSET ArtLine1
call WriteString
    
mov dl, 28
mov dh, 11
call Gotoxy
mov edx, OFFSET ArtLine2
call WriteString
    
mov dl, 28
mov dh, 12
call Gotoxy
mov edx, OFFSET ArtLine3
call WriteString
    
mov dl, 28
mov dh, 13
call Gotoxy
mov edx, OFFSET ArtLine4
call WriteString
    
mov dl, 28
mov dh, 14
call Gotoxy
mov edx, OFFSET ArtLine5
call WriteString
    
mov dl, 28
mov dh, 15
call Gotoxy
mov edx, OFFSET ArtLine6
call WriteString
    
mov dl, 28
mov dh, 16
call Gotoxy
mov edx, OFFSET ArtLine7
call WriteString
    
mov dl, 28
mov dh, 17
call Gotoxy
mov edx, OFFSET ArtLine8
call WriteString
    
mov dl, 28
mov dh, 18
call Gotoxy
mov edx, OFFSET ArtLine9
call WriteString

mov dl, 28
mov dh, 19
call Gotoxy
mov edx, OFFSET ArtLineA
call WriteString
    
mov dl, 28
mov dh, 20
call Gotoxy
mov edx, OFFSET ArtLineB
call WriteString
    
mov dl, 28
mov dh, 22
call Gotoxy
mov edx, OFFSET ArtLineC
call WriteString
    
mov eax, 3000
call Delay
    
call Clrscr
    
popad
ret
StartupScreen ENDP

; --- PAUSE MESSAGE CLEARING ROUTINE ---
ClearPauseMessage PROC
pushad
    
mov eax, 0000h 
call SetTextColor
    
mov dl, 20
mov dh, 12
call Gotoxy
    
mov al, ' '
mov ecx, PAUSE_MSG_LEN
    
ClearLoop:
call WriteChar
inc dl
call Gotoxy
loop ClearLoop
    
popad
ret
ClearPauseMessage ENDP

; --- COIN ROUTINES ---
CheckCoinCollection PROC
pushad
    
cmp coinActive, 0
je CoinCheckDone
    
mov al, yPos
cmp al, coinY
jne CoinCheckDone
    
mov al, xPos
mov bl, coinX
    
cmp al, bl
jge XPosGreater
    
sub bl, al
jmp CheckDistance

XPosGreater:
sub al, bl
mov bl, al

CheckDistance:
cmp bl, 2
jge CoinCheckDone
    
pushad
mov eax, 000Fh
call SetTextColor
mov dl, coinX
mov dh, coinY
call Gotoxy
mov al, ' '
call WriteChar
popad
    
; *** SCORE FIX: Increment score by 10 ***
mov al, score
add al, 10
mov score, al
    
mov coinActive, 0
    
call GenerateCoin
    
CoinCheckDone:
popad
ret
CheckCoinCollection ENDP

GenerateCoin PROC
pushad
    
cmp coinActive, 1
je EndGenerate
    
mov eax, RIGHT_LIMIT_X
sub eax, LEFT_LIMIT_X
inc eax
call RandomRange
mov al, al              
add al, LEFT_LIMIT_X    
mov coinX, al
    
mov eax, LANDING_Y_POS
sub eax, JUMP_HEIGHT_LIMIT_Y
inc eax
call RandomRange
mov al, al              
add al, JUMP_HEIGHT_LIMIT_Y 
mov coinY, al
    
mov coinActive, 1

EndGenerate:
popad
ret
GenerateCoin ENDP

DrawCoin PROC
cmp coinActive, 0
je EndDrawCoin
    
pushad
mov eax, 000Eh
call SetTextColor
    
mov dl, coinX
mov dh, coinY
    
call Gotoxy
mov al, 'O'
call WriteChar
    
popad
EndDrawCoin:
ret
DrawCoin ENDP

ClearOldCoin PROC
ret
ClearOldCoin ENDP
; --- END COIN ROUTINES ---


main PROC
call StartupScreen

mov dl,0
mov dh,GROUND_Y_POS
call Gotoxy
mov edx,OFFSET ground
call WriteString

call DrawPlayer
call Randomize

call GenerateCoin

gameLoop:

mov al, xPos
mov xOldPos, al
mov al, yPos
mov yOldPos, al

call ClearOldPosition
call ClearOldGoomba
call ClearOldCoin

call HandleInput

mov al, isPaused
cmp al, 1
je DrawPauseScreen

call ApplyGravity

call MoveGoomba

call CheckCollisionAndLives

call CheckCoinCollection

DrawHUD:
mov eax,000Fh
call SetTextColor
mov dl,0
mov dh,0
call Gotoxy
mov edx,OFFSET strScore
call WriteString
mov al,score
call WriteInt
         
call DrawLivesHUD
         
call DrawPlayer
call DrawGoomba
call DrawCoin

jmp SkipPauseScreen
         
DrawPauseScreen:
mov eax, 000Fh 
call SetTextColor
mov dl, 20
mov dh, 12
call Gotoxy
mov edx, OFFSET strPaused
call WriteString
    
jmp DrawHUD 
    
SkipPauseScreen:
mov eax,70
call Delay

jmp gameLoop

main ENDP

; --- JUMP AND PHYSICS ROUTINES ---
ApplyGravity PROC
; If Mario is on the ground, do nothing except apply gravity to slow down a jump.
cmp on_Ground, 1
je CheckFall

; Apply gravity acceleration to velocity: yVelocity = yVelocity + GRAVITY_ACCEL
mov al, yVelocity
add al, GRAVITY_ACCEL
mov yVelocity, al

CheckFall:
; Check for ground collision
mov al, yPos        
mov bl, yVelocity       
add al, bl      
    
; Check if predicted Y is >= GROUND_Y_POS (29) to trigger landing
cmp al, GROUND_Y_POS    
jge LandOnGround        
jmp UpdateYPosition
    
LandOnGround:
; Set Y position DIRECTLY to the fixed landing line (28)
mov al, LANDING_Y_POS   
mov yPos, al    
    
; Reset velocity and state
mov yVelocity, 0
mov on_Ground, 1        
mov current_jumps_used, 0
    
ret

UpdateYPosition:
; Apply velocity to position: yPos = yPos + yVelocity
mov al, yPos
add al, yVelocity
mov yPos, al
    
cmp yVelocity, 0
jge CheckFallDown      
mov on_Ground, 0        
    
CheckFallDown:
ret
ApplyGravity ENDP

Jump PROC
; Check if Mario has jumps left (for High Jump Mario / Double Jump)
mov al, current_jumps_used
cmp al, max_jumps_in_air
jge NoMoreJumps

; Start the jump
mov al, JUMP_VELOCITY_INIT
mov yVelocity, al    
mov on_Ground, 0    
inc current_jumps_used    
    
; (Here is where you'd call a TwoToneJumpSound routine later)
    
NoMoreJumps:
ret
JUMP endp
    
; --- INPUT HANDLING ROUTINES ---
HandleInput PROC
; Save registers used to check for pause state inside the routine
pushad

call ReadKey
cmp al, 0
je NoKey
    
mov inputChar, al

; --- NEW: PAUSE/UNPAUSE LOGIC ---
cmp inputChar, "p"
je TogglePause
    
; Exit (always allowed)
cmp inputChar,"x"
je ExitGame

; Check if paused and ignore movement/jump if true
mov al, isPaused
cmp al, 1
je NoAction ; Ignore movement/jump keys if paused

; Jump (W)
cmp inputChar,"w"
je TryJump
    
; Left (A)
cmp inputChar, "a"
je MoveLeft
    
; Right (D)
cmp inputChar, "d"
je MoveRight
    
jmp NoKey

popad
call exitGame ; Global exit call
    
NoAction:
jmp NoKey

TogglePause:
; Toggle the isPaused flag: 0 -> 1, 1 -> 0
mov al, isPaused
xor al, 1
mov isPaused, al
    
; *** FIX: CLEAR PAUSE MESSAGE WHEN UNPAUSING ***
cmp al, 0           ; Check if the NEW state is Unpaused (0)
jne SkipClear       ; If paused (1), skip clearing
call ClearPauseMessage
SkipClear:
jmp NoKey ; Consumes the 'P' key press

TryJump:
call Jump
jmp NoKey

MoveLeft:
; Predict the new position
mov al, xPos    
dec al

; Check if the predicted position is too far left (index 0 is the space)
cmp al, 0       
je NoMove       
    
; If safe, update xPos
dec xPos
jmp NoKey

MoveRight:
; Predict the new position (index in the 'ground' array)
mov ebx, 0
mov bl, xPos
inc bl          
    
; Load the character at the predicted position
mov esi, OFFSET ground
add esi, ebx
mov al, [esi]

; Check if the character is the right-boundary space or null terminator
cmp al, ' '     
je NoMove
    
cmp al, 0       
je NoMove
    
; If safe, update xPos
inc xPos
jmp NoKey

NoMove:
; Mario hit a boundary, do not update xPos
jmp NoKey

NoKey:
popad
ret
HandleInput ENDP

; --- DRAWING ROUTINES ---
DrawPlayer PROC
; draw player at (xPos,yPos):
mov dl,xPos
mov dh,yPos
    
; FIX: Set Mario's color explicitly to White on Black (0Fh)
mov eax, 000Fh
call SetTextColor
    
; CRITICAL FIX: MANUALLY OFFSET DRAWING Y BY -1 (28 -> 27)
dec dh
    
call Gotoxy
mov al,"X" ; Draw Mario
call WriteChar
ret
DrawPlayer ENDP

ClearOldPosition PROC
; This routine clears the previously drawn 'X'
mov dl, xOldPos ; Use the saved old X
mov dh, yOldPos ; Use the saved old Y
    
; FIX: Set background color to Black (0Fh) before writing space
mov eax, 000Fh
call SetTextColor
    
; CRITICAL FIX: MANUALLY OFFSET DRAWING Y BY -1 (28 -> 27)
dec dh
    
call Gotoxy
    
; Always draw a space (no hyphen trail).
mov al, " "
call WriteChar
    
ret
ClearOldPosition ENDP

; --- GOOMBA ROUTINES ---
DrawGoomba PROC
cmp goombaActive, 0
je GoombaNotActive
    
; Set text color: Red background, White foreground (0F4h)
mov eax, 0F4h
call SetTextColor
    
mov dl, goombaX
mov dh, goombaY
    
; *** FIX: MANUALLY OFFSET DRAWING Y BY -1 (28 -> 27) to match Mario's visual level ***
dec dh
    
call Gotoxy
mov al, 'G'
call WriteChar
    
GoombaNotActive:
ret
DrawGoomba ENDP

ClearOldGoomba PROC
; Clears Goomba's last position, even if it was just squashed.
cmp goombaActive, 0
je ClearGoombaNotNeeded
    
; CRITICAL FIX: Set color to default background (0Fh) before clearing
mov eax, 000Fh      
call SetTextColor
    
mov dl, goombaX
mov dh, goombaY
    
; *** FIX: MANUALLY OFFSET DRAWING Y BY -1 (28 -> 27) to match Mario's visual level ***
dec dh
    
call Gotoxy
mov al, ' ' ; Clear with space
call WriteChar

ClearGoombaNotNeeded:
ret
ClearOldGoomba ENDP

MoveGoomba PROC
pushad
    
cmp goombaActive, 0
je GoombaNoMove
    
; --- TIMER LOGIC ---
; Decrease the timer if active, and skip movement if timer > 0.
cmp goombaResetTimer, 0
je AllowMovement
    
dec goombaResetTimer ; Decrease timer (2 -> 1, then 1 -> 0)
jmp GoombaNoMove ; Skip movement if timer was > 0

AllowMovement:
; Goomba walks one step leftwards (simple behavior)
dec goombaX
    
; If Goomba walks off the screen (X=0 or less), reset it
cmp goombaX, 0
jge GoombaNoMove
    
; Reset Goomba off-screen (e.g., far right)
mov goombaX, 70
    
GoombaNoMove:
popad
ret
MoveGoomba ENDP

CheckCollisionAndLives PROC
; If Goomba is not active, skip the entire check
cmp goombaActive, 0
je CollisionCheckDone

; *** Skip collision if Goomba is protected (timer > 0) ***
cmp goombaResetTimer, 0
jne CollisionCheckDone

; --- 1. CHECK X COLLISION (Range Check) ---
mov al, xPos
mov bl, goombaX
    
cmp al, bl
jge XPosGreater_X
sub bl, al
jmp CheckDistance_X
XPosGreater_X:
sub al, bl
mov bl, al

CheckDistance_X:
cmp bl, 2
jge CollisionCheckDone 
; X-proximity confirmed!

; --- 2. CHECK VERTICAL COLLISION ---
mov al, yPos
cmp al, LANDING_Y_POS
je CheckStompOrWalkHit ; Mario is on the Goomba's plane (Y=28)
jmp CheckMidAirHit ; Mario is airborne (Y < 28)


CheckStompOrWalkHit:
; They are on the same Y-plane (Y=28). It is a STOMP if Mario was falling onto it.
mov al, yOldPos
cmp al, LANDING_Y_POS
jl StompGoomba_Start ; If yOldPos < 28, Mario was falling onto the plane.

; If yOldPos >= 28, Mario was walking into the Goomba.
jmp PlayerGotHit_Start

CheckMidAirHit:
; *** CORE FIX: If Mario is mid-air (yPos < 28), ignore horizontal collision ***
; If X-proximity is confirmed and Mario is airborne, he should safely jump over the Goomba.
jmp CollisionCheckDone


StompGoomba_Start:
; *** STOMP CONFIRMED ***
mov goombaActive, 0
pushad
mov eax, 000Fh
call SetTextColor
mov dl, goombaX
mov dh, goombaY
dec dh
call Gotoxy
mov al, ' '
call WriteChar
popad
; *** SCORE FIX: Increment score by 10 ***
mov al, score
add al, 10
mov score, al
; --- GOOMBA REGENERATION ---
mov goombaActive, 1 ; Re-activate the Goomba
mov goombaX, 70     ; Reset off-screen far right
mov goombaResetTimer, 2 ; Give it a brief protection timer

; Force a standard bounce jump
mov al, JUMP_VELOCITY_INIT
mov yVelocity, al
mov current_jumps_used, 0
jmp CollisionCheckDone

PlayerGotHit_Start:
; *** MARIO HIT CONFIRMED (Walked in) ***
dec lives
    
cmp lives, 0
jle GameOver
    
; Reset Mario to start position after losing a life
mov xPos, 1
mov yPos, LANDING_Y_POS
mov yVelocity, 0
mov on_Ground, 1
mov current_jumps_used, 0
    
; Reset Goomba for the new attempt
mov goombaActive, 1
mov goombaX, 60
mov goombaResetTimer, 2 ; Provide protection after reset
    
jmp CollisionCheckDone ; Continue to game loop

GameOver:
; *** FIX: Update HUD to show 0 lives before displaying message ***
call DrawLivesHUD 

; *** IMPLEMENT GAME OVER LOGIC HERE ***
mov dl, 30
mov dh, 15
call Gotoxy
mov edx, OFFSET GameOverMessage
call WriteString
    
mov eax, 3000   
call Delay  
call exitGame   
    
CollisionCheckDone:
ret
CheckCollisionAndLives ENDP

DrawLivesHUD PROC
mov eax, 000Fh
call SetTextColor
    
mov dl, 15
mov dh, 0
call Gotoxy
mov edx, OFFSET strLives
call WriteString
    
mov al, lives
call WriteInt
    
ret
DrawLivesHUD ENDP

END main
