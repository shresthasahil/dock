CREATE DATABASE IF NOT EXISTS employeeSystem;
USE employeeSystem;

CREATE TABLE IF NOT EXISTS employees(
    name VARCHAR(50) NOT NULL, 
    age INT unsigned, 
    country VARCHAR(50), 
    position VARCHAR(50), 
    wage FLOAT NOT NULL
);