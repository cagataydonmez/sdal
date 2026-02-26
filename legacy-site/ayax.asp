var xmlHttp;

function hmesajisle(str)
{

xmlHttp=GetXmlHttpObject()
if (xmlHttp==null)
{
document.getElementById("hmkutusu").innerHTML="Baglanti kurulamadi.."
return
} 

var url="hmesisle.asp"
var kimden="<%=request.cookies("kadi")%>"

url=url+"?mes="+encodeURI(str)
url=url+"&sid="+Math.random()
url=url+"&kimden="+encodeURI(kimden)

xmlHttp.onreadystatechange=stateChanged
xmlHttp.open("GET",url,true)
xmlHttp.send(null)
} 


function stateChanged() 
{ 
if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
{ 
	if (request.status == 200)
		document.getElementById("hmkutusu").innerHTML=xmlHttp.responseText
	else if (request.status == 12007)
         	document.getElementById("hmkutusu").innerHTML = "Internet baglantisi kurulamadi..";
	else
        	document.getElementById("hmkutusu").innerHTML = "Error: status code is " + request.status;
} 
}

function GetXmlHttpObject()
{ 
var objXMLHttp=null

if (window.XMLHttpRequest)
{
objXMLHttp=new XMLHttpRequest()
}
else if (window.ActiveXObject)
{
objXMLHttp=new ActiveXObject("Microsoft.XMLHTTP")
}
return objXMLHttp
}