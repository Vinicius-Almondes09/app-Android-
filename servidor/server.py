import socket
import struct
import os

from datetime import datetime

from detector import detectar_objetos


HOST = "0.0.0.0"
PORT = 5000


def receber_exato(cliente, quantidade):
    """
    Recebe exatamente a quantidade de bytes informada.
    """

    dados = b""

    while len(dados) < quantidade:

        pacote = cliente.recv(
            quantidade - len(dados)
        )

        if not pacote:
            return None

        dados += pacote

    return dados


def iniciar_servidor():

    servidor = socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM
    )

    servidor.setsockopt(
        socket.SOL_SOCKET,
        socket.SO_REUSEADDR,
        1
    )

    servidor.bind((HOST, PORT))

    servidor.listen()

    print("==============================")
    print(" SERVIDOR DE DETECÇÃO")
    print("==============================")
    print(f"Porta: {PORT}")
    print("Aguardando imagem...")

    while True:

        cliente, endereco = servidor.accept()

        print("\nCliente conectado:")
        print(endereco)

        try:

            # Recebe os 4 bytes contendo
            # o tamanho da imagem
            dados_tamanho = receber_exato(
                cliente,
                4
            )

            if dados_tamanho is None:
                cliente.close()
                continue

            # Converte os 4 bytes em inteiro
            tamanho_imagem = struct.unpack(
                ">I",
                dados_tamanho
            )[0]

            print(
                f"Tamanho da imagem: "
                f"{tamanho_imagem} bytes"
            )

            # Recebe os bytes da imagem
            imagem_bytes = receber_exato(
                cliente,
                tamanho_imagem
            )

            if imagem_bytes is None:
                cliente.close()
                continue

            # Cria a pasta das imagens
            os.makedirs(
                "recebidas",
                exist_ok=True
            )

            # Cria um nome utilizando
            # data e horário
            timestamp = datetime.now().strftime(
                "%Y%m%d_%H%M%S"
            )

            caminho_imagem = (
                f"recebidas/"
                f"foto_{timestamp}.jpg"
            )

            # Salva a imagem
            with open(
                caminho_imagem,
                "wb"
            ) as arquivo:

                arquivo.write(
                    imagem_bytes
                )

            print(
                f"Imagem salva em: "
                f"{caminho_imagem}"
            )

            print(
                "Realizando detecção..."
            )

            objetos = detectar_objetos(
                caminho_imagem
            )

            if objetos:

                resposta = ",".join(
                    objetos
                )

                print(
                    "Objetos detectados:",
                    objetos
                )

            else:

                resposta = (
                    "Nada Detectado"
                )

                print(
                    "Nenhum objeto detectado."
                )

            # Envia resultado
            # de volta ao aplicativo
            cliente.sendall(
                resposta.encode(
                    "utf-8"
                )
            )

        except Exception as erro:

            print(
                f"Erro: {erro}"
            )

        finally:

            cliente.close()

            print(
                "\nConexão encerrada."
            )

            print(
                "Aguardando nova imagem..."
            )


if __name__ == "__main__":
    iniciar_servidor()