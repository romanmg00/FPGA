---
schema_version: 1
id: cs256-tron-game-overview-20261014
title: CS-256 Tron Game Overview
type: note
subject: CS-256
status: draft
created_at: "2026-10-14T15:49:32"
updated_at: "2026-10-20T14:39:59"
sources:
  - "[[Nexys_A7_Game_Research_Report]]"
source_image_original_name: 1000196852.jpg
source_image_path: /home/alan/.t3/userdata/attachments/8deb73c4-238c-48c1-b122-99a7c55e771f-06331e43-61d0-48fb-9649-08c69c26a848.jpg
source_image_sha256: f6a8a3aba0fdb24fa891dbe292e018dbd5c240eef0be764ecd72bb1f0e059e10
tags:
  - fpga
  - vga
  - tron
---

# CS-256 Tron Game Overview

> [!note] Historical whiteboard record
> This note preserves the early concept and rubric visible in the source photograph. References to an unresolved Points system, a Master role, menus, and unspecified controls predate the decisions locked in [[CS-256 Tron Agreed Specification 2026-10-20]]; they are not current requirements.

This note describes the proposed game using the supplied whiteboard photograph, `1000196852.jpg`, and the user's explanation. The photograph records planning decisions, rather than a finished game screen: the left side contains the assessment rubric, the center sketches the system, and the right side lists selected game features and inputs. The current focus is the FPGA's VGA display design.

## General Concept

The project is a Tron-inspired game for **two players**, each controlling a motorcycle in a shared playing area. Each motorcycle has a position and movement speed and leaves a visible trail. The proposal includes a points/rewards system and player lives. Exact collision rules, scoring values, the initial number of lives, and victory conditions remain to be defined.

The whiteboard also identifies **one master role** associated with world settings and a configuration menu. This role configures the game environment; the sketch does not identify it as a third competing motorcycle.

The intended platform is the FPGA board discussed in [[Nexys_A7_Game_Research_Report#Executive summary|the existing hardware report]]. That report assumes a **Digilent Nexys A7-100T with an Artix-7 XC7A100T FPGA**; the physical board model remains subject to that report's identification caveat.

## Selected Game Features

The right side of the whiteboard lists the following features:

| Feature | Description recorded in the proposal |
|---|---|
| Points and rewards | Each player has a score. Rewards and powers that increase points are proposed; their effects and activation rules are not yet specified. |
| Motorcycle trails | Moving motorcycles leave trails. The annotation suggests approximately **30 pixels**, but does not establish whether this refers to length, width, or another trail dimension. |
| Points and lives indicators | Points and lives are shown for each player. The note mentions two points displays and two lives displays, with a sketch of a points/lives pair for each player. The allocation to physical display digits is not yet defined. |
| Master configuration menu | A menu allows the master role to adjust world settings. |
| Customization | Switches select motorcycle and trail colors, the background, and proposed powers/reward options. The exact switch assignments remain open. |
| Challenge setting | A switch labeled for a challenge is proposed; the behavior of that setting is not described. |

## Player Inputs and FPGA Interaction

The center and right side of the whiteboard identify three input paths:

- **PC keyboard through UART:** WASD provides directional commands. The priority notes call for checking serial keyboard communication between the computer and FPGA.
- **Directional board buttons (`BTN`):** the four-arrow sketch represents an additional movement-control input.
- **Board switches:** these support personalization and configuration choices.

The assignment of keyboard and button controls to individual players is not explicitly recorded. Points and lives displays form the visible feedback from the FPGA alongside the VGA game view.

## VGA Presentation and Current Focus

The center sketch calls for **one VGA world view**, displaying the shared playing area, both motorcycle sprites, their trails, and the selected background. This provides the visual context for player movement and the interactive map.

The immediate priority written at the bottom of the board is **VGA output with the world**, including pixel representation and sprite size. At this stage, the display work centers on defining how the world, motorcycles, and trails appear and move on screen. The serial keyboard path and directional controls are also listed as priorities to verify.

The handwritten resolution note appears to say **“Revisar 1280p”**. It is a reminder to review the video mode, rather than a confirmed resolution. The existing hardware report discusses a 640 × 480 starting mode, but the whiteboard does not settle the final choice. Resolution, pixel clock, synchronization timing, and final sprite dimensions require a separate VGA design decision.

## Assessment Rubric

The left side of the photograph is the project assessment table. Its central score column assigns the following weights; these are grading points, distinct from the players' in-game scores.

| Criterion | Points | Related game feature |
|---|---:|---|
| Object control within limits | 2.5 | Controlled motorcycle movement within the playing area's limits. |
| Interactive map | 2.5 | The shared world and its interaction with game objects. |
| FPGA input/output | 2 | Keyboard/serial input, board buttons and switches, and visible output. |
| Sprites | 2 | Graphical representation of game objects in the VGA world view. |
| Creativity | 1 | The Tron concept and selected customization, reward, and challenge features. |
| **Total** | **10** | |

This overview captures the proposed experience and the priorities visible in the photograph. It leaves detailed gameplay rules and the VGA hardware specification for subsequent design work.
