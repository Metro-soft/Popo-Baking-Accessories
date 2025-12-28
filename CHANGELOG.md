# Changelog

All notable changes to this project will be documented in this file.

## [v1.1.0] - 2025-12-28

### Added

- **Frontend Modular Architecture**: Refactored the entire frontend codebase to use a feature-based module structure (Inventory, Sales, Finance, Core).
- **User Login & Authentication**: Implemented full login flow with secure authentication using `auth.middleware.js` and `LoginScreen`.
- **Finance Backend**: Rebuilt finance backend with clean modular system for C2B (Collections) and B2C (Disbursements).
- **Middleware**: Added `auth.middleware.js` for centralized authentication handling.
- **Controllers**: Added `auth.controller.js` and updated `branch.controller.js`, `inventory.controller.js`.
- **Wallet Functionality**: Implemented persistent payment methods and transaction history.

### Changed

- **Refactor**: Moved screens and widgets into their respective feature modules (e.g., `frontend/lib/modules/sales`, `frontend/lib/modules/inventory`).
- **Database**: Updated SQL migrations for inventory transfers, cash management, and branch handling.
- **UI/UX**: Enhanced styling for Services Pie Chart and Dashboard responsiveness.

### Fixed

- **Bug Fixes**: Resolved `RenderFlex` overflow issues in `ApplicationDetailScreen`.
- **Authentication**: Fixed "Authentication token required" errors in Wallet and Payment screens.
- **Linting**: Addressed various linting errors and type safety improvements.
