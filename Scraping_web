import requests 
from bs4 import BeautifulSoup, Comment
import re  #para ver la coincidenci con correos

# 1. Definir la URL
url = 'https://www.aprende.network/ligas.html'

# 2. Realizar la solicitud GET para obtener el HTML
respuesta = requests.get(url)

# 3. Analizar el contenido con BeautifulSoup
sopa = BeautifulSoup (respuesta.content, 'html.parser')

# 4. Extraer datos (por ejemplo, todos los enlaces 'a')
enlaces = sopa.find_all('a')

# 5. Extraer los comentarios de la página
def iscomment(elem):
    return isinstance(elem, Comment)

comentarios = sopa.find_all(string=iscomment)
# Extraer correos

contenido = respuesta.text
estandar_correos = r'[a-zA-Z0-9%_+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
correos = re.findall(estandar_correos, contenido)
lista_correos = list(set(correos))

# Crear archivos 
archivo = open("Web_scraping.txt", 'w')

for enlace in enlaces:
    archivo.write(enlace.get('href') + "\n")

for comentario in comentarios:
    archivo.write(comentario + "\n")

for correo in lista_correos:
    archivo.write(correo + "\n")

archivo.close()
