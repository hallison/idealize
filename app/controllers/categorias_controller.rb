# encoding: utf-8

module Prodam::Idealize

class CategoriasController < ApplicationController
  helpers IdeiasHelper, DateHelper

  before do
    @page = controllers[:categorias]
    @situacoes = Situacao.all_by_sem_restricao(:chave).map(&:chave)
    @fab = {
      url: path_to(:categorias, :nova),
      tooltip: 'Nova categoria!'
    } if authorized?
  end

  before '/:id/?:action?' do |id, action|
    @categoria = Categoria[id.to_i]
  end

  get '/' do
    @categorias = Categoria.all
    @categoria = Categoria.new
    view 'categorias/index'
  end

  get '/nova', authorize: 'criar nova categoria' do
    @categoria = Categoria.new
    @icones = data(:icons)
    view 'categorias/form'
  end

  get '/:id' do |id|
    view 'categorias/page'
  end

  post '/', authorize: 'criar categoria' do
    @categoria = Categoria.new(params[:categoria])
    if @categoria.valid?
      @categoria.save
      message.update(level: :information, text: 'Categoria criada com sucesso!')
      redirect to("/#{@categoria.to_url_param}")
    else
      @icones = data(:icons)
      message.update(level: :error, text: 'Oops! Tem alguma coisa errada. Observe os campos em vermelho.')
      view 'categorias/form'
    end
  end

  get '/:id/editar', authorize: 'editar categoria' do |id|
    @icones = data(:icons)
    view 'categorias/form'
  end

  put '/:id', authorize: 'editar categoria' do |id|
    @categoria.set_all(params[:categoria])
    if @categoria.valid?
      @categoria.save
      message.update(level: :information, text: 'Categoria foi atualizada com sucesso!')
      redirect to(id)
    else
      message.update(level: :error, text: 'Oops! Tem alguma coisa errada. Observe os campos em vermelho.')
      @icones = data(:icons)
      view 'categorias/form'
    end
  end

  delete '/:id', authorize: 'excluir categoria'  do |id|
    @categoria.remove_all_ideias # remoção da associação com as ideias.
    @categoria.delete
    message.update(level: :information, text: 'Categoria foi excluída.')
    redirect to('/')
  end
end

end # module
