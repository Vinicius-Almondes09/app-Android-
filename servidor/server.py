import socket
import struct
import os
import threading

from datetime import datetime

from detector import detectar_objetos


HOST = "0.0.0.0"
PORT = 8080

# Porta do serviço de descoberta (UDP). O aplicativo envia
# um "ping" em broadcast e o servidor responde com a porta
# em que está escutando, evitando digitar o IP manualmente.
DISCOVERY_PORT = 8081

DISCOVERY_REQUEST = b"DETECTOR_DISCOVERY"

DISCOVERY_REPLY_PREFIX = b"DETECTOR_SERVER|"


def listar_ips_locais():
    """
    Retorna os endereços IPv4 do computador para exibir
    no console e facilitar os testes manuais.
    """

    ips = []

    try:

        infos = socket.getaddrinfo(
            socket.gethostname(),
            None,
            socket.AF_INET
        )

        for info in infos:

            ip = info[4][0]

            if ip not in ips and not ip.startswith("127."):
                ips.append(ip)

    except OSError:
        pass

    return ips


def iniciar_descoberta():
    """
    Responde pedidos de descoberta (UDP) com o IP e a porta
    do servidor. Roda em uma thread separada.

    Se o firewall bloquear a porta UDP, a descoberta automática
    deixa de funcionar, mas o envio de imagens pela porta TCP
    continua normal (basta digitar o IP no app).
    """

    udp = socket.socket(
        socket.AF_INET,
        socket.SOCK_DGRAM
    )

    udp.setsockopt(
        socket.SOL_SOCKET,
        socket.SO_REUSEADDR,
        1
    )

    udp.bind(("", DISCOVERY_PORT))

    print(
        f"Descoberta automática ativa "
        f"(UDP porta {DISCOVERY_PORT})."
    )

    while True:

        dados, endereco = udp.recvfrom(1024)

        if dados.strip() != DISCOVERY_REQUEST:
            continue

        resposta = (
            DISCOVERY_REPLY_PREFIX
            + str(PORT).encode("ascii")
        )

        udp.sendto(
            resposta,
            endereco
        )


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

    # Thread que responde o "ping" de descoberta do app.
    thread_descoberta = threading.Thread(
        target=iniciar_descoberta,
        daemon=True
    )

    thread_descoberta.start()

    print("==============================")
    print(" SERVIDOR DE DETECÇÃO")
    print("==============================")
    print(f"Porta: {PORT}")
    print("IPs deste computador:")

    ips = listar_ips_locais()

    if ips:

        for ip in ips:
            print(f"  {ip}")

    else:

        print("  (não foi possível determinar)")

    print()
    print("IMPORTANTE:")
    print("- Use no app o IP da rede ATUAL (o IP muda")
    print("  quando o notebook troca de rede: hotspot do")
    print("  celular costuma ser 192.168.43.x; cabo USB")
    print("  (tethering), 192.168.42.x).")
    print("- Se o app não conectar, libere o firewall")
    print("  (Windows, PowerShell como administrador):")
    print("  netsh advfirewall firewall add rule name=\"Detector SD\" dir=in action=allow protocol=TCP localport=8080 profile=any")
    print("  netsh advfirewall firewall add rule name=\"Detector SD Descoberta\" dir=in action=allow protocol=UDP localport=8081 profile=any")

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

            # Tamanho 0 = sonda de teste de conexão
            # (botão "Testar conexão" do aplicativo).
            # Responde na hora, sem processar imagem.
            if tamanho_imagem == 0:

                print(
                    "Teste de conexão recebido "
                    "(sonda do app). Respondendo..."
                )

                cliente.sendall(b"OK")

                continue

            print(
                f"Tamanho da imagem: "
                f"{tamanho_imagem} bytes"
            )

            inicio_bytes = datetime.now()

            # Recebe os bytes da imagem
            imagem_bytes = receber_exato(
                cliente,
                tamanho_imagem
            )

            print(
                "Bytes recebidos em "
                f"{(datetime.now() - inicio_bytes).total_seconds():.2f}s"
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
            # data e horário (com milissegundos
            # para evitar sobrescrever imagens
            # enviadas no mesmo segundo)
            timestamp = datetime.now().strftime(
                "%Y%m%d_%H%M%S_%f"
            )[:-3]

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

            inicio_deteccao = datetime.now()

            objetos = detectar_objetos(
                caminho_imagem
            )

            print(
                "Detecção concluída em "
                f"{(datetime.now() - inicio_deteccao).total_seconds():.2f}s"
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