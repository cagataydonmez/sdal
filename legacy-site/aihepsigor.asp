<script language=javascript>

function createRequest() {
   var request = false;
   try {
     request = new XMLHttpRequest();
   } catch (trymicrosoft) {
     try {
       request = new ActiveXObject("Msxml2.XMLHTTP");
     } catch (othermicrosoft) {
       try {
         request = new ActiveXObject("Microsoft.XMLHTTP");
       } catch (failed) {
         request = false;
       }  
     }
   }

   if (!request)
     alert("Error initializing XMLHttpRequest!");
   return request;
}

   function aihepsicek() {
     request = createRequest();
     var url = "aihepsi.asp";
     url=url+"?sid="+Math.random();
     request.onreadystatechange = updatePage;
     request.open("GET", url, true);
     request.send(null);
   }



   function updatePage() {
     if (request.readyState == 4 || request.readyState=="complete")
       if (request.status == 200)
         document.getElementById("aihep").innerHTML = request.responseText;
       else if (request.status == 404)
         alert("Request URL does not exist");
       else
         alert("Error: status code is " + request.status);

   }




aihepsicek();


</script>

<div id="aihep"><center><b>Lütfen bekleyiniz..<br><br><img src=yukleniyor.gif border=0></b></center></div>