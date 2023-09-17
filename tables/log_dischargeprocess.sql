CREATE TABLE `log_dischargeprocess` (
  `id` int NOT NULL AUTO_INCREMENT,
  `patientId` varchar(50) DEFAULT NULL,
  `message` varchar(4000) DEFAULT NULL,
  `created_on` datetime DEFAULT NULL,
  `created_by` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
