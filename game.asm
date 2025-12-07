INCLUDE Irvine32.inc

.data
; Physics Constants
GROUND_Y_POS EQU 29         ; The Y coordinate for both ground drawing AND collision trigger
LANDING_Y_POS EQU 28        ; The Y coordinate Mario stands on (29 - 1 = 28)
JUMP_VELOCITY_INIT SBYTE -4 
GRAVITY_ACCEL SBYTE 1     
    
; Coin Generation Limits
JUMP_HEIGHT_LIMIT_Y EQU 10  ; Max height for randomized coin generation (Y=10)
LEFT_LIMIT_X EQU 1          ; X=1 (start of ground)
RIGHT_LIMIT_X EQU 70        ; X=70 (well before the screen edge)
    
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
goombaResetTimer BYTE 0   ; Counter for reset protection (0=None, >0=Protected)

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
ArtLine5 BYTE "   / /| | |\ \     ", 0
ArtLine6 BYTE "  | / | | | \ |    ", 0
ArtLine7 BYTE "  \ \|_|_|/ /     ", 0
ArtLine8 BYTE "   /      \       ", 0
ArtLine9 BYTE "  |  SUPER MARIO  | ", 0
ArtLineA BYTE "  |  CS LAB PROJECT |", 0
ArtLineB BYTE "  \ --------------- /", 0
ArtLineC BYTE "    Ready? (3s)     ", 0

ground BYTE " --------------------------------------------------------------------------------------------------------------------------------------------------",0
strScore BYTE "Your score is: ",0
score BYTE 0
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
    
    call Clrscr ; Clear the screen first

    mov eax, 000Fh ; Set color to White on Black (0Fh)
    call SetTextColor

    ; Display the ASCII Art, starting around X=28, Y=10
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
    
    ; Pause for 3000 milliseconds (3 seconds)
    mov eax, 3000
    call Delay
    
    ; Clear screen again before entering game loop
    call Clrscr
    
    popad
    ret
StartupScreen ENDP

; --- PAUSE MESSAGE CLEARING ROUTINE ---
ClearPauseMessage PROC
    pushad
    
    ; Set text color to Black on Black to ensure a clean clear
    mov eax, 0000h 
    call SetTextColor
    
    mov dl, 20      ; X position (where message starts)
    mov dh, 12      ; Y position (where message is drawn)
    call Gotoxy
    
    mov al, ' '     ; Character to draw (space)
    mov ecx, PAUSE_MSG_LEN ; Loop counter = message length
    
ClearLoop:
    call WriteChar ; Write a space
    inc dl         ; Move cursor right one character
    call Gotoxy    ; Apply new cursor position
    loop ClearLoop
    
    popad
    ret
ClearPauseMessage ENDP

; --- COIN ROUTINES ---
GenerateCoin PROC
    pushad
    
    ; Skip if a coin is already active
    cmp coinActive, 1
    je EndGenerate
    
    ; --- Generate Random X Position ---
    mov eax, RIGHT_LIMIT_X
    sub eax, LEFT_LIMIT_X
    inc eax
    call RandomRange
    mov al, al              
    add al, LEFT_LIMIT_X    
    mov coinX, al
    
    ; --- Generate Random Y Position ---
    mov eax, LANDING_Y_POS
    sub eax, JUMP_HEIGHT_LIMIT_Y
    inc eax
    call RandomRange
    mov al, al              
    add al, JUMP_HEIGHT_LIMIT_Y 
    mov coinY, al
    
    ; Activate the coin
    mov coinActive, 1

EndGenerate:
    popad
    ret
GenerateCoin ENDP

DrawCoin PROC
    cmp coinActive, 0
    je EndDrawCoin
    
    pushad
    ; Set color to Gold (Yellow foreground, Black background: 0Eh)
    mov eax, 000Eh
    call SetTextColor
    
    mov dl, coinX
    mov dh, coinY
    
    call Gotoxy
    mov al, 'O' ; Golden Coin
    call WriteChar
    
    popad
EndDrawCoin:
    ret
DrawCoin ENDP

ClearOldCoin PROC
    ret
ClearOldCoin ENDP

CheckCoinCollection PROC
    pushad
    
    cmp coinActive, 0
    je CoinCheckDone
    
    ; --- 1. Check Y Collision (Must be at the exact same Y position) ---
    mov al, yPos
    cmp al, coinY
    jne CoinCheckDone
    
    ; --- 2. Check X Collision (Range Check for Tunneling) ---
    ; Calculate absolute difference: |xPos - coinX|
    mov al, xPos
    mov bl, coinX
    
    ; Determine the difference (xPos - coinX)
    cmp al, bl
    jge XPosGreater ; If xPos >= coinX, jump to subtraction
    
    ; If xPos < coinX, subtract al from bl (coinX - xPos)
    sub bl, al      ; bl now holds the absolute difference
    jmp CheckDistance

XPosGreater:
    ; If xPos >= coinX, subtract bl from al (xPos - coinX)
    sub al, bl      ; al now holds the absolute difference
    mov bl, al      ; Move result to bl

CheckDistance:
    ; Check if the absolute distance is 0 (overlap) or 1 (adjacent/tunneling)
    cmp bl, 2
    jge CoinCheckDone ; If distance is 2 or more, skip collection.
    
    ; --- COIN COLLECTED ---
    
    ; Clear the 'O' from the screen
    pushad
    mov eax, 000Fh ; Reset color
    call SetTextColor
    mov dl, coinX
    mov dh, coinY
    call Gotoxy
    mov al, ' '
    call WriteChar
    popad
    
    inc score           ; Increase score
    mov coinActive, 0   ; Deactivate coin
    
    ; --- Trigger a new coin generation attempt ---
    call GenerateCoin
    
CoinCheckDone:
    popad
    ret
CheckCoinCollection ENDP
; --- END COIN ROUTINES ---


main PROC
; *** NEW: CALL STARTUP SCREEN ***
call StartupScreen

; Draw Ground (only once)
mov dl,0
mov dh,GROUND_Y_POS
call Gotoxy
mov edx,OFFSET ground
call WriteString

; Draw Mario's initial position
call DrawPlayer ; Draw initial 'X'
call Randomize ; Initialize RNG

; *** NEW: GENERATE INITIAL COIN ***
call GenerateCoin

gameLoop:

; *** SAVE CURRENT POSITION BEFORE IT CHANGES ***
mov al, xPos
mov xOldPos, al
mov al, yPos
mov yOldPos, al
; ***************************************************

; 1. CLEAR MARIO'S OLD POSITION
call ClearOldPosition
; *** CLEAR GOOMBA'S OLD POSITION ***
call ClearOldGoomba
; *** CLEAR COIN (if collected) ***
call ClearOldCoin

; 2. HANDLE USER INPUT (Only P and X work when paused)
call HandleInput

; --- NEW: CHECK PAUSE STATE ---
mov al, isPaused
cmp al, 1
je DrawPauseScreen ; If Paused, skip physics/movement/collision

; --- GAME LOGIC (SKIPPED WHEN PAUSED) ---

; 3. APPLY PHYSICS (Updates yPos variable based on yVelocity)
call ApplyGravity   

; *** GOOMBA MOVEMENT LOGIC ***
call MoveGoomba

; 4. COLLISION AND LIVES CHECK
call CheckCollisionAndLives

; 5. COIN COLLECTION AND SCORE UPDATE
call CheckCoinCollection ; Checks for coin collision and generates new coin

DrawHUD: ; Label for drawing elements (used by main loop and pause screen)
; Fix: Change HUD color to Black BG (000Fh)
mov eax,000Fh ; White text (Foreground) on Black background (0h)
call SetTextColor

; draw score:
mov dl,0
mov dh,0
call Gotoxy
mov edx,OFFSET strScore
call WriteString
mov al,score
call WriteInt
        
; Draw Lives HUD
call DrawLivesHUD
        
; 6. DRAW MARIO, GOOMBA, AND COIN AT NEW POSITION
call DrawPlayer
; *** DRAW GOOMBA AT NEW POSITION ***
call DrawGoomba
; *** DRAW COIN AT NEW POSITION ***
call DrawCoin

jmp SkipPauseScreen
        
DrawPauseScreen:
; This section runs ONLY when the game is paused.
    
; --- Draw Pause Message in the center ---
mov eax, 000Fh 
call SetTextColor
mov dl, 20 ; X position
mov dh, 12 ; Y position
call Gotoxy
mov edx, OFFSET strPaused
call WriteString
    
; Continue to draw HUD and characters without moving them
jmp DrawHUD 
    
SkipPauseScreen:
; Delay to control game speed
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
cmp goombaActive, 0
je ClearGoombaNotNeeded
    
; CRITICAL FIX: Set color to default background (0Fh) before clearing
mov eax, 000Fh      
call SetTextColor
    
; Only clear the position if the Goomba is still active
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
; *** NEW: Protect registers during complex movement/reset ***
pushad
    
cmp goombaActive, 0
je GoombaNoMove
    
; If the timer is active, decrease it for one frame and exit movement
cmp goombaResetTimer, 1
je DecrementTimer
    
; Goomba walks one step leftwards (simple behavior)
dec goombaX
    
; If Goomba walks off the screen (X=0 or less), reset it
cmp goombaX, 0
jge GoombaNoMove
    
; Reset Goomba off-screen (e.g., far right) and activate timer
mov goombaX, 70
mov goombaResetTimer, 2 ; Set protection count to 2 (2 frames)
jmp GoombaNoMove

DecrementTimer:
mov goombaResetTimer, 0 ; Disable collision check for the next frame
    
GoombaNoMove:
popad
ret
MoveGoomba ENDP

CheckCollisionAndLives PROC
; If Goomba is not active, skip the entire check
cmp goombaActive, 0
je CollisionCheckDone

; *** FIX: Skip collision if Goomba is protected (timer > 0) ***
cmp goombaResetTimer, 0
jne CollisionCheckDone

; --- 1. CHECK Y COLLISION (Must be on the same landing line) ---
mov al, yPos
cmp al, goombaY
jne CollisionCheckDone

; --- 2. CHECK X COLLISION (Range Check for Tunneling) ---
; Calculate absolute difference: |xPos - goombaX|
mov al, xPos
mov bl, goombaX
    
; Determine the difference (xPos - goombaX)
cmp al, bl
jge XPosGreater ; If xPos >= goombaX, jump to subtraction
    
; If xPos < goombaX, subtract al from bl (goombaX - xPos)
sub bl, al      ; bl now holds the absolute difference
jmp CheckDistance

XPosGreater:
; If xPos >= goombaX, subtract bl from al (xPos - goombaX)
sub al, bl      ; al now holds the absolute difference
mov bl, al      ; Move result to bl

CheckDistance:
; Check if the absolute distance is 0 (exact overlap) or 1 (adjacent/tunneling)
cmp bl, 2
jge CollisionCheckDone ; If distance is 2 or more, they missed each other.
; Tunneling is fixed!

; --- COLLISION DETECTED (Absolute distance is 0 or 1, and Y is equal) ---
    
; Check yVelocity to determine if Mario is falling (stomp)
mov al, yVelocity
cmp al, 0
jle PlayerHitCheckGround ; If yVelocity <= 0, go check if he's on the ground
    
; If we reach here, yVelocity > 0 (Falling) -> Stomp!
StompGoomba:
mov goombaActive, 0     
; Force a bounce jump (Mario should bounce up after a stomp)
mov al, JUMP_VELOCITY_INIT
add al, al      
mov yVelocity, al
jmp CollisionCheckDone

PlayerHitCheckGround:
; *** NEW FIX: ONLY LOSE LIFE IF MARIO IS ON THE GROUND (WALKING INTO GOOMBA) ***
mov al, on_Ground
cmp al, 1
jne CollisionCheckDone ; If Mario is NOT on the ground (i.e., jumping/in air), IGNORE HIT!

PlayerGotHit:
; Mario loses a life
dec lives
    
; Check for Game Over
cmp lives, 0
jle GameOver
    
; Reset Mario to start position after losing a life
mov xPos, 1
mov yPos, LANDING_Y_POS
mov yVelocity, 0
mov on_Ground, 1
    
; Reset Goomba for the new attempt
mov goombaActive, 1
mov goombaX, 60
    
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
; Fix: MUST use White on Black (000Fh)
mov eax, 000Fh ; White text on Black background
call SetTextColor
    
; Display "MARIO LIVES: "
mov dl, 15
mov dh, 0
call Gotoxy
mov edx, OFFSET strLives
call WriteString
    
; Display remaining lives
mov al, lives
call WriteInt
    
ret
DrawLivesHUD ENDP
; --- END COIN ROUTINES ---

END main
