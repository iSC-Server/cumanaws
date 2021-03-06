class CarritoController < ApplicationController
  
  def index
    render :locals => { :articulos => articulos }
  end
  
  def agregar_dominio
    if params[:id] && params[:nombre]
      plan_dominio = PlanDominio.where(:_id => params[:id], :borrado => {'$exists' => false}).first
      if plan_dominio
        compra = Compra.new
        if cuenta_signed_in?
          compra.cuenta=current_cuenta
        else
          unless defined?(cookies[:tmp_carrito]) && BSON::ObjectId.legal?(cookies[:tmp_carrito])
            cookies[:tmp_carrito]={
              :value => BSON::ObjectId.new,
              :expires => 1.year.from_now
            }
          end
          compra.tmp_carrito = BSON::ObjectId.from_string(cookies[:tmp_carrito])
        end
        compra.plan_dominio = plan_dominio
        compra.nombre = params[:nombre]
        compra.duracion = 12
        compra.precio = plan_dominio.precio_anual
        compra.save
      end
    end
    redirect_to carrito_path
  end
  
  def agregar_hospedaje
    if params[:id]
      plan_hospedaje = PlanHospedaje.where(:_id => params[:id], :borrado => {'$exists' => false}).first
      if plan_hospedaje
        compra = Compra.new
        if cuenta_signed_in?
          compra.cuenta=current_cuenta
        else
          unless defined?(cookies[:tmp_carrito]) && BSON::ObjectId.legal?(cookies[:tmp_carrito])
            cookies[:tmp_carrito]={
              :value => BSON::ObjectId.new,
              :expires => 1.year.from_now
            }
          end
          compra.tmp_carrito = BSON::ObjectId.from_string(cookies[:tmp_carrito])
        end
        compra.plan_hospedaje = plan_hospedaje
        compra.duracion = 1
        compra.precio = plan_hospedaje.precio_mensual
        compra.save
      end
    end
    redirect_to carrito_path
  end
  
  def remover
    if cuenta_signed_in?
        articulo = Compra.where('_id' => params[:id], 'cuenta_id' => current_cuenta.id, :borrado.exists => false).first
     elsif defined?(cookies[:tmp_carrito]) && BSON::ObjectId.legal?(cookies[:tmp_carrito])
        articulo = Compra.where('_id' => params[:id], 'tmp_carrito' => cookies[:tmp_carrito], :borrado.exists => false).first
     end
    if articulo
      articulo.borrado = true
      articulo.save
    end
    redirect_to carrito_path
    # render 'carrito/index.html', :locals => { :articulos => articulos }
  end
  
  def editar
    if(params[:id] && params[:duracion])
      if cuenta_signed_in?
        articulo = Compra.where('_id' => params[:id], 'cuenta_id' => current_cuenta.id, :borrado.exists => false).first
      elsif defined?(cookies[:tmp_carrito]) && BSON::ObjectId.legal?(cookies[:tmp_carrito])
        articulo = Compra.where('_id' => params[:id], 'tmp_carrito' => cookies[:tmp_carrito], :borrado.exists => false).first
      end
      if articulo
        if articulo.plan_dominio
          articulo.duracion = 12
          articulo.precio = articulo.plan_dominio.precio_anual
        elsif articulo.plan_hospedaje
          articulo.duracion = ( params[:duracion] == '12' ? 12 : ( params[:duracion] == '6' ? 6 : (params[:duracion] == '3' ? 3 : 1) ) )
          articulo.precio = ( params[:duracion] == '12' ? articulo.plan_hospedaje.precio_anual : ( params[:duracion] == '6' ? articulo.plan_hospedaje.precio_mensual*6 : (params[:duracion] == '3' ? articulo.plan_hospedaje.precio_mensual*3 : articulo.plan_hospedaje.precio_mensual) ) )
        end
        articulo.save
      end
    end
    redirect_to carrito_path
  end
  
  def articulos
    if cuenta_signed_in?
      compras = Compra.where('cuenta_id' => current_cuenta.id, :borrado.exists => false, :enviado.exists => false)
    elsif defined?(cookies[:tmp_carrito]) && BSON::ObjectId.legal?(cookies[:tmp_carrito])
      compras = Compra.where('tmp_carrito' => cookies[:tmp_carrito], :borrado.exists => false)
    else
      compras = []
    end
    articulos = []
    compras.each do |compra|
      articulo = {:_id => compra._id}
      if compra.plan_dominio
        articulo[:servicio] = 'dominio'
        articulo[:dominio] = compra.plan_dominio.dominio
        articulo[:nombre] = compra.nombre
      elsif compra.plan_hospedaje
        articulo[:servicio] = 'hospedaje'
        articulo[:plan] = compra.plan_hospedaje.nombre
        articulo[:espacio] = compra.plan_hospedaje.espacio
      end
      articulo[:duracion] = compra.duracion
      articulo[:precio] = compra.precio
      articulos.push(articulo)
    end
    return articulos
  end
  
  def pagar
    precio_total = Compra.where('cuenta_id' => current_cuenta.id, :borrado.exists => false, :enviado.exists => false).sum(:precio)
    saldo = Saldo.where(:cuenta_id => current_cuenta._id, :activo.gte => precio_total ).first
    if saldo
      orden_compra = OrdenCompra.new
      orden_compra.nro = OrdenCompra.max(:nro).to_i + 1
      orden_compra.precio_total = precio_total
      orden_compra.enviado = true
      Compra.where('cuenta_id' => current_cuenta.id, :borrado.exists => false, :enviado.exists => false).each do |articulo|
        articulo.orden_compra = orden_compra
        articulo.enviado = true
        articulo.save
      end
      saldo.activo = saldo.activo - precio_total
      movimiento_saldo = MovimientoSaldo.new
      movimiento_saldo.cuenta = current_cuenta
      movimiento_saldo.orden_compra = orden_compra
      movimiento_saldo.saldo = precio_total
      movimiento_saldo.tipo = false
      movimiento_saldo.motivo = 'compra'
      movimiento_saldo.save
      saldo.save
      orden_compra.save
      render :locals => { :articulos => Compra.where(:orden_compra => orden_compra ), :orden_compra => orden_compra }
    else
      redirect_to carrito_path
    end
  end
  
end