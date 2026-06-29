<?php
/*
 * Gerador de hash Bcrypt para PHP antigo
 * Não usa password_hash()
 * Compatível com PHP 5.x, desde que o servidor tenha suporte a CRYPT_BLOWFISH
 */

if (!defined('CRYPT_BLOWFISH') || CRYPT_BLOWFISH != 1) {
    echo "Erro: esta versão/instalação do PHP não tem suporte a Bcrypt/Blowfish.\n";
    exit(1);
}

if ($argc < 2) {
    echo "Uso: php gerar_bcrypt_antigo.php 'sua_senha'\n";
    exit(1);
}

$senha = $argv[1];
$custo = 10;

/*
 * Detecta se o PHP suporta prefixo $2y$.
 * Se não suportar, usa $2a$, que também é Bcrypt.
 */
function suporta_2y()
{
    $teste = crypt('teste', '$2y$10$abcdefghijklmnopqrstuu');
    return strlen($teste) === 60 && substr($teste, 0, 4) === '$2y$';
}

function gerar_bytes_aleatorios($tamanho)
{
    if (function_exists('openssl_random_pseudo_bytes')) {
        $forte = false;
        $bytes = openssl_random_pseudo_bytes($tamanho, $forte);

        if ($bytes !== false && strlen($bytes) === $tamanho) {
            return $bytes;
        }
    }

    if (is_readable('/dev/urandom')) {
        $fp = fopen('/dev/urandom', 'rb');
        if ($fp !== false) {
            $bytes = fread($fp, $tamanho);
            fclose($fp);

            if ($bytes !== false && strlen($bytes) === $tamanho) {
                return $bytes;
            }
        }
    }

    /*
     * Último fallback.
     * Não é o ideal criptograficamente, mas evita quebrar em PHP muito antigo.
     */
    $bytes = '';
    for ($i = 0; $i < $tamanho; $i++) {
        $bytes .= chr(mt_rand(0, 255));
    }

    return $bytes;
}

function gerar_salt_bcrypt()
{
    $bytes = gerar_bytes_aleatorios(16);

    /*
     * Bcrypt usa salt com 22 caracteres.
     */
    $salt = base64_encode($bytes);
    $salt = str_replace('+', '.', $salt);
    $salt = str_replace('=', '', $salt);

    return substr($salt, 0, 22);
}

$prefixo = suporta_2y() ? '2y' : '2a';

$salt = gerar_salt_bcrypt();
$formato = '$' . $prefixo . '$' . sprintf('%02d', $custo) . '$' . $salt;

$hash = crypt($senha, $formato);

if (strlen($hash) !== 60) {
    echo "Erro ao gerar hash Bcrypt.\n";
    exit(1);
}

echo "Senha original: " . $senha . "\n";
echo "Hash Bcrypt:\n";
echo $hash . "\n";