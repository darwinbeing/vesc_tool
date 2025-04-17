/*
    Copyright 2022 Benjamin Vedder	benjamin@vedder.se

    This file is part of VESC Tool.

    VESC Tool is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    VESC Tool is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    */

#ifndef CODELOADER_H
#define CODELOADER_H

#include <QObject>
#include <QDir>
#include "vescinterface.h"
#include "datatypes.h"

class CodeLoader : public QObject
{
    Q_OBJECT
public:
    explicit CodeLoader(QObject *parent = nullptr);

    VescInterface *vesc() const;
    Q_INVOKABLE void setVesc(VescInterface *vesc);

    Q_INVOKABLE bool lispErase(int size);
    QString reduceLispFile(QString fileData);
    QByteArray lispPackImports(QString codeStr, QString editorPath = QDir::currentPath(), bool reduceLisp = false);
    QPair<QString, QList<QPair<QString, QByteArray> > > lispUnpackImports(QByteArray data);
    bool lispUpload(VByteArray vb);
    bool lispUpload(QString codeStr, QString editorPath = QDir::currentPath(), bool reduceLisp = false);
    Q_INVOKABLE bool lispUploadFromPath(QString path, bool reduceLisp);
    bool lispStream(VByteArray vb, qint8 mode);
    Q_INVOKABLE bool lispStreamString(QString str, qint8 mode) {
        return lispStream(str.toUtf8(), mode);
    }
    QString lispRead(QWidget *parent, QString &lispPath);

    Q_INVOKABLE bool qmlErase(int size);
    QByteArray qmlCompress(QString script);
    bool qmlUpload(QByteArray scripr, bool isFullscreen);

    QByteArray packVescPackage(VescPackage pkg);
    VescPackage unpackVescPackage(QByteArray data);
    bool installVescPackage(VescPackage pkg);
    Q_INVOKABLE bool installVescPackage(QByteArray data);
    Q_INVOKABLE bool installVescPackageFromPath(QString path);

    Q_INVOKABLE QVariantList reloadPackageArchive();
    Q_INVOKABLE bool downloadPackageArchive();

    Q_INVOKABLE void abortDownloadUpload();

    bool createPackageFromDescription(QString path, VescPackage *pkgRes = nullptr, bool reduceLisp = false);
    Q_INVOKABLE bool shouldShowPackage(VescPackage pkg);
    Q_INVOKABLE static bool shouldShowPackageFromRxp(VescPackage pkg, FW_RX_PARAMS rxp, bool *runOk = nullptr);

signals:
    void downloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void lispUploadProgress(qint64 bytes, qint64 bytesTotal);

private:
    VescInterface *mVesc;
    bool mAbortDownloadUpload;
    bool getImportFromLine(QString line, QString &path, QString &tag, bool &isInvalid);

};

#endif // CODELOADER_H
