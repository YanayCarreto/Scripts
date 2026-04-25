import requests from bs4 import BeautifulSoup, Comment
import re  #para ver la coincidenci con correos

# 1. Definir la URL
url = 'https://www.aprende.network/ligas.html'

# 2. Realizar la solicitud GET para obtener el HTML
respuesta = requests.get(url)

# 3. Analizar el contenido con BeautifulSoup
sopa = BeautifulSoup (respuesta.content, 'html.parser')

# 4. Leer el diccionario de palabras/archivos a buscar
with open('diccionario.txt', 'r', encoding='utf-8') as f:
    palabras = [linea.strip() for linea in f if linea.strip()]

# 5. Buscar cada palabra en el HTML completo
html_como_texto = str(sopa)  

for palabra in palabras:

    if palabra.lower() in html_como_texto.lower():
        print(f" Encontrado '{palabra}'")
    else:
        print(f" No encontrado '{palabra}'")



