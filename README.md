# SmartSpend

SmartSpend is a personal finance management application built as a university project for the course **Mobilni Informaciski Sistemi** at the Faculty of Computer Science and Engineering - Ss. Cyril and Methodius University in Skopje (FINKI/UKIM).

The app helps users track income and expenses, scan receipts to automatically log transactions, manage savings goals, and split expenses with friends through shared group wallets.

## Team

| Name | Index |
|------|-------|
| Artan Ebibi | 221513 |
| Edon Fetaji | 221517 |
| Edi Rizvani | 221587 |

## Architecture

The project follows a microservices architecture, fully containerized with Docker.

- **core-api** - Main backend service written in Go using the Gin framework. Handles authentication, transaction management, statistics, savings goals, group wallets, and integrates with the Gemini API for intelligent receipt processing.
- **PostgreSQL** - Relational database for all persistent data.
- **Docker Compose** - Orchestrates the full stack for local development.

## Features

### Transaction Management
Full CRUD for income and expense transactions. Users can manually create entries or scan a receipt - the OCR service extracts the text, Gemini interprets it, and a transaction is created automatically. The system also handles the case where the uploaded image is not a valid receipt, returning an appropriate error to the user.

### Receipt Scanning (OCR + Gemini)
Upload a photo of a receipt and the pipeline handles the rest:
1. The image is sent to the OCR service which runs Tesseract with preprocessing
2. The extracted text is forwarded to the Gemini API
3. Gemini parses the text into structured transaction data (amount, category, date, etc.)
4. A new transaction is created in the user's account

### Financial Statistics
- Spending breakdown by category (percentage-based pie chart data)
- Monthly spending totals over a date range
- Total income vs. total expenses
- Average income and average expense over a period

### Savings Goals
Users can create, update, and track savings goals with target amounts.

### Group Wallets
A shared expense feature that lets multiple users pool and split costs:

- **Create & join wallets** - A user creates a wallet and shares the generated invite code. Others join by entering the code.
- **Link transactions** - Members attach their own existing expense transactions to the wallet and define how the cost is split (equal or custom amounts). The sum of shares must match the transaction price exactly.
- **Balance computation** - The backend computes each member's net balance across all linked transactions. A positive balance means the member is owed money; negative means they owe.
- **Settlement suggestions** - A greedy minimum-transactions algorithm produces the smallest possible set of transfers needed to settle all debts (at most `n-1` transfers for `n` members).
- **Settlement recording** - When members pay each other back in real life, either party records the settlement. Settlements are append-only for a clean audit trail and are automatically factored into the next balance computation.

### Authentication
Sign in / sign up via Google and Apple OAuth. Token rotation with access + refresh tokens.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Go, Gin framework |
| AI/LLM | Google Gemini API |
| Database | PostgreSQL |
| Containerization | Docker, Docker Compose |
| Authentication | Google OAuth, Apple Sign-In |

## Getting Started

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Setup

1. Clone the repository:
```sh
git clone https://github.com/artanebibi/SmartSpend.git
cd SmartSpend
```

2. Create .env files

**frontend/**
```
GOOGLE_ANDROID_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
GRADLE_CERTIFICATE_HASH=xxx
BACKEND_URL=xxx
```

**backend/**
```
PORT=8080
BUILD_ENV=docker
APP_ENV=DOCKER
DB_HOST=postgres
DB_PORT=5432
DB_USERNAME=username
DB_PASSWORD=pass
DB_DATABASE=smartspend
DB_SCHEMA=public
GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
BASE_URL=xxx
GOOGLE_IOS_CLIENT_ID=xxx.apps.googleusercontent.com
ACCESS_TOKEN_SECRET_KEY=xxx
GEMINI_API_KEY=xxx
```

3. Run API and Database
```bash
cd backend/
docker-compose up --build -d
```

4. Run Frontend
```bash
cd frontend/
flutter run
```
