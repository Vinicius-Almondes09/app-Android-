from ultralytics import YOLO


# Carrega o modelo de detecção
modelo = YOLO("yolo11n.pt")

 

def detectar_objetos(caminho_imagem):
    """
    Recebe o caminho de uma imagem e retorna
    uma lista contendo os objetos detectados.
    """

    resultados = modelo(caminho_imagem)

    objetos = []

    for resultado in resultados:

        for caixa in resultado.boxes:

            classe = int(caixa.cls[0])

            nome_objeto = modelo.names[classe]

            if nome_objeto not in objetos:
                objetos.append(nome_objeto)

    return objetos