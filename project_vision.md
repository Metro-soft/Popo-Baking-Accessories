# Popo Baking Accessories - Project Vision & Architecture

## System Overview

**Popo Baking Accessories** is a centralized Enterprise Resource Planning (ERP) and Point of Sale (POS) system designed to manage a complex, multi-location baking supply business.

The system is definitively **NOT** just a single-store POS. It is the central nervous system for the entire enterprise.

## Core Architectural Pillars

### 1. Multi-Branch & Multi-Warehouse

* **Centralized Control:** A single dashboard manages operations across multiple physical branch locations and separate warehouse facilities.
* **Inventory Movement:** The system tracks stock levels not just in total, but per location. It handles stock transfers between warehouses and branches.
* **Scalability:** New branches or warehouses can be added to the system and immediately integrated into the central data flow.

### 2. Unified Inventory & Sales Management

* **Real-Time Sync:** Sales at any POS terminal in any branch immediately update the central inventory records.
* **Global Visibility:** Admins can see "what is selling where" in real-time.
* **Procurement:** Purchasing and supplier management are centralized to leverage bulk buying and efficient distribution to branches.

### 3. Integrated E-commerce / Website Control

* **One Backend to Rule Them All:** The same backend and database that powers the in-store POS also controls the public-facing website/e-commerce store.
* **Product Sync:** A product added to the ERP is automatically available for the website (if enabled). Price changes reflect instantly across both physical and digital channels.
* **Order fulfillment:** Online orders flow into the same "Sales Orders" pipeline as physical sales, allowing for unified fulfillment dispatch.

## Technology Stack

* **Frontend:** Flutter (Mobile/Desktop/Web) - Focused on a Premium, High-End UI (`0xFFA01B2D` Deep Red Brand Color).
* **Backend:** Node.js (Express)
* **Database:** PostgreSQL
* **Infrastructure:** Designed to be cloud-hosted for central access.

## Current Development Focus

We are currently refining the **Sales Module**, specifically optimizing the UI/UX for "Payments In", POS interactions, and ensuring the "Premium" look and feel is consistent. However, every feature must be built with the **Multi-Branch/Multi-Warehouse** architecture in mind (e.g., typically requiring `branch_id` or `warehouse_id` filters on data queries).
