
SELECT
    id,
    username,
    role,
    CASE
        WHEN password_encrypted = crypt('admin123', password_encrypted)
            THEN 'admin123'
        WHEN password_encrypted = crypt('courier1', password_encrypted)
            THEN 'courier1'
        WHEN password_encrypted = crypt('disp2024', password_encrypted)
            THEN 'disp2024'
        ELSE '(пароль неизвестен)'
    END AS password_decrypted
FROM SystemUsers;
