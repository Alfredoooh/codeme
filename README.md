Pular para o conteúdo principal
Logotipo do Firebase
Configurações do projeto
Configurações do projeto
Geral
Cloud Messaging
Integrações
Contas de serviço
Privacidade dos dados
Usuários e permissões
Alertas
Seu projeto
Nome do projeto
nexa-app
ID do projeto
nexa-app-e4bb3
Número do projeto
534344296518
Ambiente
Esta configuração personaliza o projeto para diferentes fases do ciclo de vida do aplicativo
Tipo de ambiente
Não especificado
Configurações públicas
Essas configurações controlam instâncias do seu projeto que são mostradas ao público
Nome exibido ao público 
Nexa
E-mail para suporte
alfredopjonas@gmail.com
Seus aplicativos
Configuração do SDK
Precisa reconfigurar os SDKs do Firebase para seu app? Consulte novamente as instruções de configuração do SDK ou apenas faça o download do arquivo de configuração que contém as chaves e identificadores do seu app.
ID do aplicativo
1:534344296518:android:e92db4bf418666af2b8247
Apelido do app
Nexa
Nome do pacote
com.jj_group.nexa
Impressões digitais do certificado SHA
Tipo
Ações
Adicionar app Android
Você também pode registrar um app Android usando um agente de programação de IA
Concluída
Editável
3
4


Adicionar o SDK do Firebase
Instruções para Gradle
|
UnityC++
tip:
Você ainda usa a sintaxe buildscript para gerenciar plug-ins? Saiba como adicionar plug-ins do Firebase usando essa sintaxe.
Para tornar os valores de configuração do arquivo google-services.json acessíveis aos SDKs do Firebase, você precisa do plug-in do Gradle para os Serviços do Google.


DSL do Kotlin (build.gradle.kts)

Groovy (build.gradle)
Adicione o plug-in como uma dependência do arquivo build.gradle.kts no nível do projeto:

Arquivo do Gradle no nível raiz (nível do projeto) (<project>/build.gradle.kts):
plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.5.0" apply false

}
Em seguida, no arquivo build.gradle.kts do módulo (nível do app) , adicione o plug-in google-services e todos os SDKs do Firebase que você quer usar no app:

Arquivo do Gradle do módulo (nível do app) (<project>/<app-module>/build.gradle.kts):
plugins {
  id("com.android.application")

  // Add the Google services Gradle plugin
  id("com.google.gms.google-services")

  ...
  }

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.18.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  // https://firebase.google.com/docs/android/setup#available-libraries
}
Ao usar a BoM do Firebase para Android, o app sempre vai utilizar versões da biblioteca do Firebase compatíveis. Saiba mais
Depois de adicionar o plug-in e os SDKs desejados, sincronize seu projeto do Android com os arquivos do Gradle.




Turbine seu desenvolvimento! Use o Cloud Shell para acessar a CLI integrada do Firebase e executar emuladores do Firebase diretamente em uma máquina virtual.
