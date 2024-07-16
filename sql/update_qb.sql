DELIMITER //

IF NOT EXISTS( (SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
        AND COLUMN_NAME='balance' AND TABLE_NAME='player_vehicles') ) THEN
    ALTER TABLE player_vehicles ADD balance int(11) NOT NULL DEFAULT 0;
END IF//

IF NOT EXISTS( (SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
        AND COLUMN_NAME='paymentamount' AND TABLE_NAME='player_vehicles') ) THEN
    ALTER TABLE player_vehicles ADD paymentamount int(11) NOT NULL DEFAULT 0;
END IF//

IF NOT EXISTS( (SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
        AND COLUMN_NAME='paymentsleft' AND TABLE_NAME='player_vehicles') ) THEN
    ALTER TABLE player_vehicles ADD paymentsleft int(11) NOT NULL DEFAULT 0;
END IF//

IF NOT EXISTS( (SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE()
        AND COLUMN_NAME='financetime' AND TABLE_NAME='player_vehicles') ) THEN
    ALTER TABLE player_vehicles ADD financetime int(11) NOT NULL DEFAULT 0;
END IF//

DELIMITER ;