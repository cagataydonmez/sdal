<%
resim = request.querystring("r")


set img = server.createobject("W3Image.Image")

img.LoadImage("C:\Domains\sdal.org\wwwroot\vesikalik\"&resim)

img.StreamImage Response,"JPG",24
%>