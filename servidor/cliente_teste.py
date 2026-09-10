"""
Cliente de teste para o servidor de detecção.

Envia uma imagem via Socket TCP seguindo o protocolo do trabalho:
    4 bytes (tamanho da imagem, Big Endian) + bytes da imagem JPEG

Uso:
    python cliente_teste.py [caminho_da_imagem]
    python cliente_teste.py [caminho_da_imagem] --host 192.168.0.105 --porta 8080

Se nenhum caminho for informado, uma imagem de teste simples é
gerada automaticamente com OpenCV.

Opções extras:
    --host IP        IP do servidor (padrão: 127.0.0.1)
    --porta PORTA    Porta do servidor (padrão: 8080)
    --testar         Apenas testa a conexão (sonda de tamanho 0),
                     sem enviar imagem
    --descobrir      Descobre o servidor na rede via broadcast
                     UDP (mesmo mecanismo do botão do app)
"""

import socket
import struct
import sys
import time

HOST = "127.0.0.1"
PORT = 8080

# Mesmos valores definidos no server.py
DISCOVERY_PORT = 8081

DISCOVERY_REQUEST = b"DETECTOR_DISCOVERY"

DISCOVERY_REPLY_PREFIX = b"DETECTOR_SERVER|"


def analisar_argumentos(argv):
    """
    Separa o caminho da imagem (posicional) das opções
    --host, --porta e --testar.
    """

    caminho = None

    host = HOST

    porta = PORT

    testar = False

    descobrir = False

    i = 0

    while i < len(argv):

        arg = argv[i]

        if arg == "--host":

            i += 1

            host = argv[i]

        elif arg == "--porta":

            i += 1

            porta = int(argv[i])

        elif arg == "--testar":

            testar = True

        elif arg == "--descobrir":

            descobrir = True

        elif caminho is None:

            caminho = arg

        else:

            print(f"Argumento inesperado: {arg}")

            sys.exit(1)

        i += 1

    return caminho, host, porta, testar, descobrir


def descobrir_servidor(espera=3.0):
    """
    Envia um broadcast UDP pedindo por servidores.
    Retorna (ip, porta) do primeiro que responder
    ou None se ninguém responder no período.
    """

    udp = socket.socket(
        socket.AF_INET,
        socket.SOCK_DGRAM
    )

    udp.setsockopt(
        socket.SOL_SOCKET,
        socket.SO_BROADCAST,
        1
    )

    udp.settimeout(0.5)

    fim = time.time() + espera

    try:

        while time.time() < fim:

            udp.sendto(
                DISCOVERY_REQUEST,
                ("255.255.255.255", DISCOVERY_PORT)
            )

            try:

                dados, endereco = udp.recvfrom(1024)

            except socket.timeout:
                continue

            if dados.startswith(DISCOVERY_REPLY_PREFIX):

                porta = int(
                    dados.decode("ascii")
                    .split("|")[1]
                )

                return endereco[0], porta

    finally:
        udp.close()

    return None


def testar_conexao(host, porta):
    """
    Envia apenas o cabeçalho com tamanho 0, que o servidor
    entende como teste de conexão e responde "OK".
    """

    print(f"Testando conexão com {host}:{porta}...")

    with socket.create_connection(
        (host, porta),
        timeout=10,
    ) as cliente:

        cliente.sendall(struct.pack(">I", 0))

        resposta = cliente.recv(1024)

    print(
        "Conexão OK! Servidor respondeu:",
        resposta.decode("utf-8"),
    )


def gerar_imagem_teste(caminho="imagem_teste.jpg"):
    """Gera uma imagem simples para testar o servidor."""

    import cv2
    import numpy as np

    imagem = np.full((480, 640, 3), 240, dtype=np.uint8)

    cv2.putText(
        imagem,
        "Teste",
        (220, 250),
        cv2.FONT_HERSHEY_SIMPLEX,
        2,
        (0, 0, 255),
        4,
    )

    cv2.imwrite(caminho, imagem)

    return caminho


def main():

    caminho, host, porta, testar, descobrir = analisar_argumentos(
        sys.argv[1:]
    )

    if descobrir:

        resultado = descobrir_servidor()

        if resultado is None:

            print(
                "Nenhum servidor encontrado.\n"
                "Confira se o server.py está rodando e se "
                "os dois computadores estão na mesma rede."
            )

            sys.exit(1)

        ip, porta_descoberta = resultado

        print(
            f"Servidor encontrado: {ip}:{porta_descoberta}"
        )

        return

    if testar:
        testar_conexao(host, porta)

        return

    if caminho is None:
        caminho = gerar_imagem_teste()

    with open(caminho, "rb") as arquivo:
        imagem = arquivo.read()

    print(
        f"Enviando {caminho} para {host}:{porta} "
        f"({len(imagem)} bytes)..."
    )

    with socket.create_connection(
        (host, porta),
        timeout=60,
    ) as cliente:

        # 4 bytes com o tamanho da imagem
        cliente.sendall(
            struct.pack(">I", len(imagem))
        )

        # Bytes da imagem JPEG
        cliente.sendall(imagem)

        cliente.shutdown(socket.SHUT_WR)

        resposta = b""

        while True:

            pacote = cliente.recv(4096)

            if not pacote:
                break

            resposta += pacote

    print(
        "Objetos detectados:",
        resposta.decode("utf-8"),
    )


if __name__ == "__main__":
    main()