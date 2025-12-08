🚗🔥 Blaze Rush – x86 Assembly Game
A Real-Time Lane-Switching Racing Game Built Entirely in 16-Bit Assembly

By Mutahir Shahzad — Roll No. 24L-0580

🎮 Game Overview

Blaze Rush is a fast-paced 2D ASCII racing game built using x86 Assembly (8086), running via BIOS interrupts, keyboard & timer ISR multitasking, and direct video memory rendering.

The player controls a red car moving between three lanes, avoiding blue obstacle cars, collecting coins, and managing fuel — all in real time.

This project demonstrates:

Real-time game loop

Interrupt-driven input handling

Event-based spawning system

Custom rendering engine

Sound effects driven by PIT

✨ Key Features
🚘 Player Movement

Lane switching (left/right)

Up/down vertical adjustments

Collision-safe lane shifting

Smooth non-blocking controls (keyboard ISR)

🚙 Obstacle System

Randomized spawning

Lane-based validation to prevent overlaps

Multi-row obstacle movement

Automatic cleanup when off-screen

💰 Coins & Fuel Items

Separate spawning logic

Safe-distance checks from obstacles

Real-time pickup detection

Sound effects & score/fuel updates

⛽ Fuel Management

Gradual consumption

Fuel bar with color feedback:

🟩 Green (50–100%)

🟨 Yellow (31–49%)

🟥 Red (0–30%)

Game ends when fuel hits 0

🎵 Sound System

PIT-based tones for:

Coin pickup

Fuel pickup

Crash event

Timer ISR generates frequency control

🧱 Rendering Engine

Draws everything manually on video memory (0xB800):

Borders

Road

Lane dividers

Player car

Blue cars

Coins

Fuel pickups

Fuel bar

Score

⏸ Pause & Exit System

ESC → Pause menu

Y → Exit

N → Continue

Confirmation boxes rendered in text mode

📝 Player Detail Input

A clean UI to capture:

Player name

Player roll number

🏁 Game Over Screens

Different endings:

Car crash

Fuel depletion
