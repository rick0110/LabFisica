void setup() {
  // Cria a comunicação serial para exibir os valores no monitor serial
  Serial.begin(115200);
  Serial.println("\n\n\n           Voltímetro 6 canais se chMax=5");
  Serial.println("A0(V)   A1(V)   A2(V)   A3(V)   A4(V)   A5(V) timestamp(ms)");
}

void loop() {
  float tensao[6];
  int chMax=0; // use 5 para os 6 canais, ou 0 para 1 canal
  int chN;  

  // Mede o valor de 0 a 1023 e converte para tensão
  //           o (float) faz um coerção, pois o comando analogRead retorna um numero inteiro e a tensão é um float
  for (chN=0;chN<=chMax;chN++) {
   tensao[chN] = (float)analogRead(chN)*5/1023;      
   Serial.print(tensao[chN],4); // com 4 digitos
    Serial.print("\t");
   }
   Serial.print(millis());
    Serial.print("\n");
  // Cria um pequeno atraso entre cada medição
  delay(1000);
}
