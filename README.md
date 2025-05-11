# Electric Vehicle Charging Marketplace

A decentralized application built on the Stacks blockchain for managing EV charging station payments and reservations.

## Overview

This project provides a transparent and efficient marketplace for electric vehicle charging stations using blockchain technology. It allows station owners to register their chargers, EV owners to find and reserve charging stations, and facilitates secure payments for charging sessions.

## Features

- Register charging stations with location, pricing, and technical details
- Update station availability and pricing
- Make reservations for charging sessions
- Start and complete charging sessions with automatic payment
- Rate charging stations and view average ratings
- Platform fee management for marketplace sustainability

## Smart Contract Functions

### Admin Functions
- `set-admin`: Update the contract administrator
- `set-platform-fee`: Set the platform fee percentage

### Station Owner Functions
- `register-charging-station`: Register a new charging station
- `update-station-availability`: Update the availability of a station
- `update-station-pricing`: Update the price per kWh for a station
- `complete-charging-session`: Complete a charging session (can also be done by user)

### EV Owner Functions
- `make-reservation`: Make a reservation for a charging station
- `start-charging-session`: Start a charging session
- `complete-charging-session`: Complete a charging session
- `rate-charging-station`: Rate a charging station after use

### Read-Only Functions
- `get-charging-station`: Get details of a charging station
- `get-reservation`: Get details of a reservation
- `get-user-rating`: Get a user's rating for a station
- `get-station-average-rating`: Get the average rating for a station
- `get-platform-fee`: Get the current platform fee percentage

## Development

This project is built using Clarity, the smart contract language for the Stacks blockchain.

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://github.com/blockstack/stacks.js)