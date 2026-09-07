Trabalho 02 – Sistemas Distribuídos

Aplicativo Android para Detecção de Objetos

Este projeto foi desenvolvido como parte da Atividade 02 da disciplina de Sistemas Distribuídos**.

O objetivo é desenvolver uma aplicação distribuída composta por um aplicativo Android desenvolvido em Flutter** e um servidor desenvolvido em Python**.

O aplicativo é responsável por capturar uma fotografia e enviá-la ao servidor por meio de uma conexão Socket TCP**. O servidor recebe a imagem, realiza a detecção dos objetos utilizando o modelo YOLO11n** e retorna ao aplicativo os objetos identificados.

---

1. Tecnologias utilizadas

Servidor

Python

Socket TCP

Ultralytics

YOLO11n

OpenCV

Aplicativo Android

Flutter

Dart

Pacote camera

Pacote image

Biblioteca dart:io

Socket TCP

O pacote camera é utilizado para acessar a câmera e capturar a fotografia.

O pacote image é utilizado para preparar a fotografia em formato JPEG, com qualidade aproximada de 80 e largura máxima de 1280 pixels.

A biblioteca dart:io, pertencente ao próprio Dart, é utilizada para estabelecer a comunicação Socket TCP com o servidor.

---

2. Estrutura do projeto

A estrutura principal do projeto é:


trabalho_02_SD/

│

├── servidor/

│   ├── server.py

│   ├── detector.py

│   ├── cliente_teste.py

│   ├── requirements.txt

│   ├── yolo11n.pt

│   └── recebidas/

│

├── app_detector/

│   ├── android/

│   ├── lib/

│   │   └── main.dart

│   └── pubspec.yaml

│

└── README.md


O arquivo cliente_teste.py foi utilizado como ferramenta auxiliar para testar o servidor antes da integração com o aplicativo Android.

A implementação principal do aplicativo está concentrada no arquivo:


app_detector/lib/main.dart


Os demais arquivos da estrutura Flutter foram gerados automaticamente pelo próprio framework.

---

3. Funcionamento do sistema

O sistema utiliza uma arquitetura cliente-servidor.

O funcionamento previsto é:

1. O servidor Python é iniciado e fica aguardando uma conexão.

2. O usuário informa no aplicativo o endereço IP e a porta do servidor.

3. O usuário seleciona Tirar e Analisar**.

4. O aplicativo captura uma fotografia.

5. A imagem é preparada em formato JPEG.

6. Caso necessário, a largura é reduzida para no máximo 1280 pixels.

7. A imagem é codificada com qualidade JPEG 80.

8. O aplicativo estabelece uma conexão Socket TCP com o servidor.

9. São enviados 4 bytes contendo o tamanho da imagem.

10. Em seguida, são enviados os bytes da fotografia.

11. O servidor recebe e salva a fotografia.

12. O YOLO11n realiza a detecção dos objetos.

13. O servidor envia o resultado para o aplicativo.

14. O aplicativo apresenta os objetos identificados ou Nada Detectado.

15. O usuário pode capturar outra fotografia para realizar uma nova análise.

Fluxo:


Aplicativo Android

       │

       ▼

Captura da fotografia

       │

       ▼

JPEG

Qualidade 80

Largura ≤ 1280 px

       │

       ▼

Socket TCP

       │

       ├── 4 bytes: tamanho

       └── N bytes: fotografia

              │

              ▼

       Servidor Python

              │

              ▼

          YOLO11n

              │

              ▼

      Objetos detectados

              │

              ▼

        Resposta TCP

              │

              ▼

      Aplicativo Android

              │

              ▼

       Resultado na tela


---

4. Protocolo de comunicação

A comunicação entre o aplicativo e o servidor utiliza Socket TCP**.

Foi definido o seguinte protocolo:


4 bytes + N bytes


Os primeiros 4 bytes** representam o tamanho da fotografia.

Os próximos N bytes** correspondem ao conteúdo da imagem JPEG.

O tamanho é representado por um inteiro de 32 bits utilizando Big Endian**.

Fluxo da comunicação:


Cliente                         Servidor

   │                               │

   │── 4 bytes: tamanho ──────────►│

   │                               │

   │── N bytes: imagem JPEG ──────►│

   │                               │

   │                         Processamento

   │                            YOLO11n

   │                               │

   │◄──── resultado da análise ────│

   │                               │


---

5. Servidor Python

O servidor foi implementado no arquivo:


servidor/server.py


Suas principais responsabilidades são:

criar o Socket TCP;

aguardar conexões;

receber o tamanho da imagem;

receber os bytes da fotografia;

salvar a fotografia;

executar a detecção de objetos;

enviar o resultado ao cliente;

continuar aguardando novas conexões.

O servidor utiliza:


HOST = 0.0.0.0

PORT = 5000


O endereço 0.0.0.0 permite que o servidor aceite conexões pelas interfaces de rede disponíveis no computador.

---

6. Detecção de objetos

A detecção é realizada utilizando a biblioteca Ultralytics** e o modelo:


YOLO11n


O detector está implementado em:


servidor/detector.py


O arquivo utilizado pelo modelo é:


yolo11n.pt


Exemplos de objetos que podem ser retornados:


person

car

chair

backpack


O aplicativo possui tratamento para apresentar alguns desses resultados em português, por exemplo:


Pessoa detectada

Carro detectado

Cadeira detectada

Mochila detectada


Quando nenhum objeto é identificado:


Nada Detectado


---

7. Imagens recebidas

As fotografias recebidas pelo servidor são armazenadas em:


servidor/recebidas/


Cada fotografia recebe um nome contendo a data e o horário.

Exemplo:


foto_20260907_125700.jpg


Isso evita que uma nova fotografia substitua automaticamente a anterior.

---

8. Dependências do servidor

As dependências Python estão registradas em:


servidor/requirements.txt


Conteúdo:


ultralytics

opencv-python


---

9. Como executar o servidor Python

Acessar a pasta


cd "C:\Users\Vinicius\Documents\trabalho_02_SD\servidor"


Criar o ambiente virtual

Na primeira configuração:


python -m venv venv


Ativar o ambiente virtual


.\venv\Scripts\Activate.ps1


Instalar as dependências


pip install -r requirements.txt


Executar o servidor


python server.py


Resultado esperado:


==============================

 SERVIDOR DE DETECÇÃO

==============================

Porta: 5000

Aguardando imagem...


O servidor deve permanecer em execução durante a utilização do aplicativo.

---

10. Teste do servidor

Antes da integração com o aplicativo Flutter, foi utilizado o cliente auxiliar:


servidor/cliente_teste.py


Para executar:


python cliente_teste.py


O teste confirmou o funcionamento do envio da imagem, processamento pelo servidor e retorno da resposta.

Em um dos testes realizados, foi obtido:


Objetos detectados:

Nada Detectado


Esse resultado confirmou também o funcionamento do tratamento para imagens em que nenhum objeto reconhecido pelo modelo é identificado.

---

11. Configuração de IP e porta

O aplicativo deve utilizar o endereço IPv4 do computador onde o servidor Python está sendo executado.

No Windows, o endereço pode ser consultado com:


ipconfig


Deve-se localizar:


Endereço IPv4


Exemplo:


192.168.0.105


Nesse exemplo:


IP: 192.168.0.105

Porta: 5000


O endereço apresentado é apenas um exemplo. Deve ser utilizado o IPv4 real do computador durante o teste.

Em um dispositivo Android físico, não deve ser utilizado 127.0.0.1 ou localhost para acessar diretamente o servidor executado no computador.

O computador e o dispositivo Android devem possuir conectividade de rede entre si.

---

12. Configuração do Flutter

O Flutter SDK foi instalado em:


C:\Users\Vinicius\develop\flutter


Como o Flutter ainda não foi adicionado ao PATH do Windows, durante o desenvolvimento os comandos podem ser executados utilizando:


& "$env:USERPROFILE\develop\flutter\bin\flutter.bat"


O projeto Flutter foi criado com:


& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" create app_detector


Esse comando criou automaticamente a estrutura inicial do projeto Flutter.

O código padrão de demonstração gerado pelo Flutter em lib/main.dart foi posteriormente substituído pela implementação do aplicativo de detecção de objetos.

---

13. Dependências do aplicativo Flutter

Acessar a pasta:


cd "C:\Users\Vinicius\Documents\trabalho_02_SD\app_detector"


O pacote camera foi instalado com:


& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" pub add camera


O pacote image foi instalado com:


& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" pub add image


Esses comandos atualizaram automaticamente o arquivo:


pubspec.yaml


As dependências utilizadas pelo aplicativo são:


camera

image


A comunicação TCP utiliza:


dart:io


Como dart:io pertence ao próprio Dart, não é necessária uma instalação adicional.

---

14. Implementação do aplicativo

O código principal está em:


app_detector/lib/main.dart


O aplicativo implementa:

inicialização da câmera;

campo para IP do servidor;

campo para porta;

visualização da câmera;

botão Tirar e Analisar**;

captura da fotografia;

correção da orientação da imagem;

redução para largura máxima de 1280 pixels;

codificação JPEG com qualidade 80;

conexão Socket TCP;

envio do tamanho em 4 bytes;

envio dos bytes da fotografia;

recebimento da resposta do servidor;

apresentação da fotografia capturada;

apresentação do resultado da detecção;

tratamento de Nada Detectado;

possibilidade de realizar uma nova análise.

---

15. Permissões do Android

Para permitir o acesso à câmera e à rede, foram adicionadas ao arquivo:


app_detector/android/app/src/main/AndroidManifest.xml


as seguintes permissões:


\<uses-permission android:name="android.permission.CAMERA" />

\<uses-permission android:name="android.permission.INTERNET" />


A permissão CAMERA permite o acesso à câmera do dispositivo.

A permissão INTERNET permite a comunicação do aplicativo com o servidor Python pela rede.

---

16. Verificação do código Flutter

Após a implementação, o código foi verificado utilizando:


& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" analyze


Durante a verificação inicial foram encontrados problemas relacionados ao recebimento da resposta TCP e ao teste padrão criado pelo Flutter.

O recebimento da resposta foi ajustado para trabalhar corretamente com os bytes retornados pelo Socket.

O arquivo de teste padrão:


test/widget_test.dart


foi removido porque correspondia ao aplicativo de contador criado automaticamente pelo Flutter e não representava mais a aplicação desenvolvida.

Após os ajustes, foi executado novamente:


& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" analyze


Resultado:


Analyzing app_detector...

No issues found!


Portanto, a análise estática do código Flutter foi concluída sem erros.

---

17. Configuração do ambiente Android

Para verificar o ambiente de desenvolvimento foi utilizado:

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" doctor

O Flutter SDK utilizado durante o desenvolvimento foi instalado em:

C:\Users\Vinicius\develop\flutter

Como o comando flutter não estava adicionado ao PATH do Windows, os comandos foram executados diretamente por meio do arquivo flutter.bat.

Para preparar o ambiente Android, o Android Studio foi instalado com:

winget install --id Google.AndroidStudio -e --source winget

Por meio do ambiente Android foram configurados os componentes necessários para a compilação. Durante o processo foram utilizados:

Android SDK Platform 36
NDK 28.2.13676358

O Android SDK utilizado ficou localizado em:

C:\Users\Vinicius\AppData\Local\Android\Sdk

Durante a configuração, o Flutter apresentou um aviso relacionado à verificação das licenças das ferramentas de linha de comando. Entretanto, durante a compilação a licença do Android SDK Platform 36 foi reconhecida como aceita e a plataforma foi instalada/configurada corretamente.

Também foi necessário instalar o NDK 28.2.13676358, utilizado pelo processo de compilação Android.

Problema encontrado com o caminho do projeto

Inicialmente o projeto estava em uma pasta chamada:

trabalho_02_(SD)

Os parênteses no nome do diretório causaram problema durante a execução do Gradle no Windows. Por isso, a pasta foi renomeada para:

trabalho_02_SD

Depois dessa alteração o Gradle conseguiu continuar o processo de compilação.

Problema de memória durante a compilação

Na primeira compilação Android, o processo llvm-strip do NDK tentou processar a biblioteca Flutter para a arquitetura x86_64 e apresentou:

LLVM ERROR: out of memory
Allocation failed

Como o objetivo do projeto é executar o aplicativo em um dispositivo Android físico compatível com ARM64, a compilação foi limitada a essa arquitetura.

O comando que efetivamente concluiu a geração do APK foi:

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" build apk --debug --target-platform android-arm64

Resultado obtido:

Built build\app\outputs\flutter-apk\app-debug.apk

Portanto, o APK de depuração foi gerado com sucesso em:

app_detector/build/app/outputs/flutter-apk/app-debug.apk

Os avisos sobre versões mais recentes de algumas dependências não impediram a compilação e não foi necessário atualizar esses pacotes.

18. Como executar o aplicativo Flutter

18.1 Para quem baixar/clonar o projeto

É necessário ter o Flutter e o ambiente Android configurados no computador. Depois, acesse a pasta do aplicativo:

cd app_detector

Como camera e image já estão declarados no pubspec.yaml, não é necessário adicioná-los novamente. Basta restaurar as dependências do projeto:

flutter pub get

Verifique o ambiente:

flutter doctor

Verifique os dispositivos Android disponíveis:

flutter devices

Com um celular Android conectado e com a Depuração USB habilitada, execute:

flutter run

Se for necessário gerar o APK ARM64 utilizado neste projeto:

flutter build apk --debug --target-platform android-arm64

O arquivo será gerado em:

build/app/outputs/flutter-apk/app-debug.apk

18.2 Comandos utilizados no computador de desenvolvimento

Como o Flutter não estava no PATH, durante o desenvolvimento foram utilizados os comandos:

cd "C:\Users\Vinicius\Documents\trabalho_02_SD\app_detector"

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" pub get

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" analyze

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" devices

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" run

Para gerar o APK:

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" build apk --debug --target-platform android-arm64

No aplicativo deverá ser informado:

IP: endereço IPv4 do computador que executa server.py
Porta: 5000

O IPv4 pode ser consultado no computador com:

ipconfig

O servidor Python deve estar em execução antes de solicitar a análise da fotografia.

19. Capturas de tela

As capturas de tela serão adicionadas após o teste completo da integração.

Tela do aplicativo


[CAPTURA DE TELA SERÁ INSERIDA APÓS O TESTE]


Imagem capturada


[CAPTURA DE TELA SERÁ INSERIDA APÓS O TESTE]


Resultado da detecção


[CAPTURA DE TELA SERÁ INSERIDA APÓS O TESTE]


---

20. Status do desenvolvimento

Concluído

Estrutura do servidor Python

Ambiente virtual Python

Dependências do servidor

Servidor Socket TCP

Protocolo de 4 bytes + fotografia

Salvamento das fotografias com timestamp

Ultralytics

YOLO11n

Detecção de objetos

Retorno do resultado pelo servidor

Tratamento de Nada Detectado

Teste local cliente-servidor em Python

Instalação do Flutter SDK

Criação do projeto app_detector

Instalação do pacote camera

Instalação do pacote image

Implementação do main.dart

Configuração da permissão CAMERA

Configuração da permissão INTERNET

Implementação da captura da fotografia no código

Implementação do processamento JPEG no código

Implementação do envio TCP no código

Implementação do recebimento da resposta no código

Implementação da exibição do resultado no código

Verificação com flutter analyze

Correção dos problemas encontrados pelo analisador

flutter analyze concluído com No issues found!

Instalação do Android Studio

Configuração do Android SDK

Android SDK Platform 36 disponível

NDK 28.2.13676358 disponível

Correção do caminho do projeto de trabalho_02_(SD) para trabalho_02_SD

Compilação do aplicativo para Android ARM64

Geração do app-debug.apk

Pendente somente de teste final

Conectar um dispositivo Android físico

Verificar o dispositivo com flutter devices

Executar o aplicativo no Android

Autorizar e testar a câmera no dispositivo

Testar Flutter → servidor Python

Confirmar o recebimento da resposta no Android

Testar uma segunda fotografia/nova análise

Adicionar as capturas de tela finais

Atualizar esta documentação com o resultado do teste final

21. Situação atual

O servidor Python está implementado e foi validado com o cliente Python auxiliar. Nesse teste foi confirmado o protocolo TCP utilizado pelo trabalho: envio de 4 bytes com o tamanho da fotografia, envio da imagem, processamento pelo YOLO11n e retorno da resposta pelo servidor.

O aplicativo Flutter também está implementado. O main.dart realiza a inicialização da câmera, captura da fotografia, correção de orientação, redimensionamento quando necessário, codificação JPEG com qualidade 80, comunicação Socket TCP e apresentação do resultado.

A análise estática foi concluída com:

Analyzing app_detector...
No issues found!

O ambiente necessário para a compilação Android também foi configurado. Foram utilizados o Android SDK Platform 36 e o NDK 28.2.13676358.

Durante o desenvolvimento ocorreram dois problemas importantes:

O nome antigo da pasta trabalho_02_(SD) interferia na execução do Gradle no Windows. O diretório foi renomeado para trabalho_02_SD.

A compilação envolvendo x86_64 apresentou falta de memória no llvm-strip. Para o APK destinado ao celular Android ARM64, foi utilizada a compilação específica para android-arm64.

O comando que concluiu a compilação foi:

& "$env:USERPROFILE\develop\flutter\bin\flutter.bat" build apk --debug --target-platform android-arm64

Resultado:

Built build\app\outputs\flutter-apk\app-debug.apk

Assim, neste momento o servidor, o aplicativo, a análise estática e a geração do APK estão concluídos.

A etapa restante é o teste de integração em um celular Android físico:

Android/Flutter
      ↓
Captura da fotografia
      ↓
JPEG – qualidade 80
largura máxima 1280 px
      ↓
Socket TCP
      ↓
4 bytes + fotografia
      ↓
Servidor Python
      ↓
YOLO11n
      ↓
Objetos detectados
      ↓
Resposta TCP
      ↓
Resultado no aplicativo

Após esse teste, devem ser inseridas no README as capturas da tela do aplicativo, da imagem capturada e do resultado da detecção.