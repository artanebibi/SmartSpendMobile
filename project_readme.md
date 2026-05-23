# SmartSpend

SmartSpend is a personal finance management application designed to help you track your income and expenses, manage savings goals, and gain insights into your spending habits. It features a Go-based microservices architecture, with a core API for business logic and a dedicated service for Optical Character Recognition (OCR) to automatically create transactions from receipt images.

## Architecture

The project is built using a microservices architecture, containerized with Docker for ease of development and deployment.

-   **`core-api`**: The main backend service built with Go and the Gin framework. It handles user authentication, data management (transactions, categories, savings), and exposes a RESTful API. It also integrates with the Gemini API for intelligent processing of OCR data.
-   **`ocr-service`**: A lightweight Go service dedicated to processing receipt images. It uses Tesseract OCR (`gosseract`) with various image preprocessing techniques to extract text from receipts.
-   **`PostgreSQL`**: A relational database used for persisting all application data.
-   **`Docker Compose`**: Orchestrates the services, making it simple to run the entire application stack locally.

## Features

-   **User Authentication**: Secure sign-in and sign-up with Google and Apple.
-   **Transaction Management**: Full CRUD (Create, Read, Update, Delete) operations for income and expense transactions.
-   **Receipt Scanning**: Upload a photo of a receipt, and the OCR and Gemini services will automatically extract details to create a new transaction.
-   **Financial Statistics**: Get detailed insights into your spending with various reports:
    -   Spending breakdown by category (percentage-based).
    -   Total spending per month.
    -   Total and average income/expense over a given period.
-   **Savings Goals**: Set and track your savings goals.
-   **Real-time Updates**: A WebSocket endpoint for potential real-time features.
-   **RESTful API**: A well-defined API for all application functionalities.

## Getting Started

To get the application running on your local machine, you'll need Docker and Docker Compose installed.

### Prerequisites

-   [Docker](https://docs.docker.com/get-docker/)
-   [Docker Compose](https://docs.docker.com/compose/install/)

### Installation

1.  **Clone the repository:**
    ```sh
    git clone https://github.com/artanebibi/SmartSpend.git
    cd SmartSpend
    ```

2.  **Create an environment file:**
    Create a `.env` file in the root directory of the project and populate it with the necessary environment variables. Use the following template:

    ```env
    # Application Environment
    APP_ENV=local
    PORT=8080

    # PostgreSQL Database Configuration
    DB_HOST=postgres
    DB_PORT=5432
    DB_DATABASE=smartspend
    DB_USERNAME=user
    DB_PASSWORD=password
    DB_SCHEMA=public

    # Service URLs
    OCR_URL=http://ocr-service:5000

    # Google OAuth Client IDs
    GOOGLE_WEB_CLIENT_ID=your_google_web_client_id
    GOOGLE_IOS_CLIENT_ID=your_google_ios_client_id

    # Gemini API Key
    GEMINI_API_KEY=your_gemini_api_key
    ```

3.  **Run the application:**
    Use Docker Compose to build and start all the services.

    ```sh
    docker-compose up --build
    ```

    The `core-api` will be available at `http://localhost:8080` (or the `PORT` you specified).

## API Endpoints

The API is organized into several resource groups. All endpoints requiring authentication must include an `Authorization: Bearer <access_token>` header.

### Authentication (`/api/auth`)

-   `POST /google`: Sign in or sign up with a Google ID token.
-   `POST /apple`: Sign in or sign up with Apple credentials.
-   `POST /logout`: Log out the current user (requires authentication).

### Token Management (`/api/token`)

-   `POST /`: Rotate an expired access token using a valid refresh token.

### User (`/api/user`)

-   `GET /me`: Get the current authenticated user's profile data.
-   `GET /balances`: Get the current user's balance and monthly saving goal.
-   `PATCH /update`: Update user information.

### Transactions (`/api/transaction`)

-   `GET /`: Get all transactions for a user within a date range (e.g., `?from=...&to=...`).
-   `GET /:id`: Get a specific transaction by its ID.
-   `POST /`: Create a new transaction.
-   `POST /receipt`: Create a new transaction by uploading a receipt image (form-data with key `image`).
-   `PATCH /:id`: Update an existing transaction.
-   `DELETE /:id`: Delete a transaction.

### Categories (`/api/category`)

-   `GET /`: Get a list of all available transaction categories.

### Savings (`/api/saving`)

-   `GET /`: Get all savings goals for a user.
-   `GET /:id`: Get a specific saving goal by ID.
-   `POST /`: Create a new saving goal.
-   `PATCH /:id`: Update an existing saving goal.
-   `DELETE /:id`: Delete a saving goal.

### Statistics (`/api/statistics`)

All statistics endpoints require `from` and `to` date query parameters.
-   `GET /pie`: Get total expenses per category as a percentage.
-   `GET /monthly`: Get total expenses for each month in the date range.
-   `GET /total-spent`: Get the total income and total expenses.
-   `GET /average`: Get the average income and average expense.

## Development

The `core-api` service includes a `Makefile` with several useful commands for local development. Navigate to the `core-api` directory to use them.

```sh
cd core-api
```

-   **Build the application:**
    ```sh
    make build
    ```

-   **Run the application locally (without Docker):**
    ```sh
    make run
    ```

-   **Run the test suite:**
    ```sh
    make test
    ```

-   **Run integration tests against a test database:**
    ```sh
    make itest
    ```

-   **Enable live-reloading with `air`:**
    This command will automatically install `air` if it's not found and watch for file changes to rebuild and restart the server.
    ```sh
    make watch
    ```

-   **Manage the Docker environment:**
    ```sh
    # Start all services
    make docker-run

    # Stop all services
    make docker-down


