<template>
  <section>
    <br />
    <div class="title">About Page</div>
    <br />
    <img
      class="img"
      src="@/assets/fh-joanneum-logo.jpg"
      alt="FH-Joanneum logo"
    />
    <div class="about">
      <p>
        Diese Inventory Site wurde im Rahmen der Lehrveranstaltung
        „Projektarbeit“ im 3. Semester des Masterstudiengangs
        Informationsmanagement, in der Fachrichtung IT-Architecture, an der FH
        JOANNEUM, im Wintersemester 2021/22, erstellt. Die Ziele waren die
        Erstellung einer Microservice Architektur, welche mit Hilfe von Azure
        Ressourcen erstellt wurde. Dabei wurden zahlreiche Ressourcen
        eingesetzt, wie z.B. eine Webapp für das Frontend, eine Functionapp zum
        Deployment des Backends. Dabei wurde auch sehr viel Wert auf das Login
        mithilfe von Microsoft Identity gesetzt. Diese Seite dient dazu, mit
        Hilfe einer PC-Kamera oder durch den einfachen Upload eines Bildes, das
        Objekt mit Hilfe der vortrainierten Custom Vision zu klassifizieren und
        zu speichern. Weiters hat man die Möglichkeit das hochgeladene Bild zu
        bearbeiten und eine Beschreibung hinzuzufügen.
      </p>
      <br />
    </div>
  </section>
</template>

<style>
.about {
  padding-left: 25%;
  padding-right: 25%;
  text-align: justify;
}

.img {
  padding-bottom: 2%;
  padding-left: 25%;
  padding-right: 25%;
}
</style>