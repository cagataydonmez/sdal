<%

iwidth = request.querystring("iwidth")
resim = request.querystring("r")

if Len(iwidth) = 0 then
iwidth = 138
end if

iwidth = cInt(iwidth)

set img = server.createobject("W3Image.Image")

img.LoadImage("C:\Domains\sdal.org\wwwroot\vesikalik\"&resim)

w = img.Width

if (w > iwidth) then
imgscale = CDbl(iwidth/w)
img.Scale 100*imgscale,0
end if

'################### Image renk düzenlemeleri ###################
if session("grayscale") = "evet" then
img.GrayScale
end if

if session("threshold") = "evet" then
img.Threshold(80)
end if

'################### Image renk düzenlemeleri bitiþi ###################

img.StreamImage Response,"JPG",24
%>